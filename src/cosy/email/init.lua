return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local CSocket       = loader.load "cosy.socket"
  local I18n          = loader.load "cosy.i18n"
  local Logger        = loader.load "cosy.logger"
  local Redis         = loader.load "cosy.redis"
  local Scheduler     = loader.load "cosy.scheduler"
  local Value         = loader.load "cosy.value"
  local Smtp          = loader.require "socket.smtp"
  local Ssl           = loader.require "ssl"
  if not Ssl then
    Ssl = _G.ssl
  end

  Configuration.load {
    "cosy.email",
    "cosy.nginx",
  }

  local i18n   = I18n.load "cosy.email"
  i18n._locale = Configuration.locale

  if _G.js then
    error "Not available"
  end

  local Email = {}

  -- First case: detection, using blocking sockets
  -- Second case: email sending, using non-blocking sockets

  local make_socket = {}

  function make_socket.async ()
    local result = CSocket ()
    result:settimeout (Configuration.smtp.timeout)
    result:setoption ("keepalive"  , true)
    result:setoption ("reuseaddr"  , true)
    result:setoption ("tcp-nodelay", true)
    return result
  end

  -- http://lua-users.org/wiki/StringRecipes
  local email_pattern = "<[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?>"

  local tls_alias = {
    ["TLS v1.2"] = "tlsv1_2",
    ["TLS v1.1"] = "tlsv1_1",
    ["TLS v1.0"] = "tlsv1",
    ["SSL v3"  ] = "sslv3",
    ["SSL v2"  ] = "sslv23",
  }
  -- http://stackoverflow.com/questions/11070623/lua-send-mail-with-gmail-account
  local Tcp = {}

  local function forward__index (self, key)
    return getmetatable (self) [key]
        or function (_, ...)
             return self.socket [key] (self.socket, ...)
           end
  end

  function Tcp.PLAINTEXT ()
    return function (_, make)
      return make ()
    end
  end

  local TLS_mt = {
    __index = forward__index,
  }
  function TLS_mt:connect (host, port)
    self.socket = self.make ()
    if not self.socket:connect (host, port) then
      return false
    end
    self.socket = Ssl.wrap (self.socket, {
      mode     = "client",
      protocol = tls_alias [self.protocol],
    })
    return self.socket:dohandshake ()
  end
  function Tcp.TLS (protocol, make)
    return function ()
      return setmetatable ({
        socket   = make (),
        protocol = protocol,
        make     = make,
      }, TLS_mt)
    end
  end

  local STARTTLS_mt = {
    __index = forward__index,
  }
  function STARTTLS_mt:connect (host, port)
    self.socket = self.make ()
    if not self.socket:connect (host, port) then
      return nil, "connection failed"
    end
    self.socket:send ("EHLO cosy\r\n")
    repeat
      local line = self.socket:receive "*l"
    until line == nil
    self.socket:send "STARTTLS\r\n"
    self.socket:receive "*l"
    self.socket = Ssl.wrap (self.socket, {
      mode     = "client",
      protocol = tls_alias [self.protocol],
    })
    local result = self.socket:dohandshake ()
    self.socket:send ("EHLO cosy\r\n")
    return result
  end
  function Tcp.STARTTLS (protocol, make)
    return function ()
      return setmetatable ({
        socket   = make (),
        protocol = protocol,
        make     = make,
      }, STARTTLS_mt)
    end
  end

  function Email.discover ()
    local domain        = Configuration.http.hostname
    local host          = Configuration.smtp.host
    local username      = Configuration.smtp.username
    local password      = Configuration.smtp.password
    local methods       = { Configuration.smtp.method }
    if #methods == 0 then
      methods = {
        "STARTTLS",
        "TLS",
        "PLAINTEXT",
      }
    end
    local protocols = { Configuration.smtp.protocol }
    if #protocols == 0 then
      protocols = {
        "TLS v1.2",
        "TLS v1.1",
        "TLS v1.0",
        "SSL v3",
        "SSL v2",
      }
    end
    local ports     = { Configuration.smtp.port }
    if #ports == 0 then
      ports = {
        25,
        587,
        465
      }
    end
    for _, method in ipairs (methods) do
      local protos = (method == "PLAIN") and { "nothing" } or protocols
      for _, protocol in ipairs (protos) do
        for _, port in ipairs (ports) do
          Logger.debug {
            _        = i18n ["smtp:discover"],
            host     = host,
            port     = port,
            method   = method,
            protocol = protocol,
          }
          local ok, s = pcall (Smtp.open, host, port, Tcp [method] (protocol, make_socket.async))
          if ok then
            ok = pcall (s.auth, s, username, password, s:greet (domain))
            if ok then
              Configuration.smtp.port     = port
              Configuration.smtp.method   = method
              Configuration.smtp.protocol = protocol
              return true
            else
              s:close ()
            end
          end
        end
      end
    end
  end

  function Email.send (message)
    Scheduler.addthread (function ()
      local locale    = message.locale or Configuration.locale
      local si18n     = I18n.new (locale)
      local localized = si18n (message)
      message.from    = localized.from   .message
      message.to      = localized.to     .message
      message.subject = localized.subject.message
      message.body    = localized.body   .message
      if not Email.ready
      or not Smtp.send {
        from     = message.from:match (email_pattern),
        rcpt     = message.to  :match (email_pattern),
        source   = Smtp.message {
          headers = {
            from    = message.from,
            to      = message.to,
            subject = message.subject,
          },
          body = message.body
        },
        user     = Configuration.smtp.username,
        password = Configuration.smtp.password,
        server   = Configuration.smtp.host,
        port     = Configuration.smtp.port,
        create   = Tcp [Configuration.smtp.method] (Configuration.smtp.protocol, make_socket.async),
      } then
        local redis = Redis.client ()
        redis:rpush (Configuration.smtp.redis_key, Value.expression (localized))
      end
    end)
  end

  Scheduler.addthread (function ()
    local ok, result = pcall (Email.discover)
    if not ok or not result then
      Email.ready = false
      Logger.warning {
        _ = i18n ["smtp:not-available"],
      }
    else
      Email.ready = true
      Logger.info {
        _        = i18n ["smtp:available"],
        host     = Configuration.smtp.host,
        port     = Configuration.smtp.port,
        method   = Configuration.smtp.method,
        protocol = Configuration.smtp.protocol,
      }
    end
  end)

  return Email

end
