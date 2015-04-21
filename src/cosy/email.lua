local loader = require "cosy.loader"
local ssl    = require "ssl"
local smtp   = loader.hotswap "socket.smtp"

if _G.js then
  error "Not available"
end

local Email = {}

-- First case: detection, using blocking sockets
-- Second case: email sending, using non-blocking sockets

local make_socket = {}

function make_socket.sync ()
  local socket = loader.hotswap "socket"
  local result = socket.tcp ()
  result:settimeout (loader.configuration.smtp.timeout._)
  result:setoption ("keepalive", true)
  result:setoption ("reuseaddr", true)
  result:setoption ("tcp-nodelay", true)
  return result
end

function make_socket.async ()
  local result = loader.socket ()
  result:settimeout (loader.configuration.smtp.timeout._)
  result:setoption ("keepalive", true)
  result:setoption ("reuseaddr", true)
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
  __index     = forward__index,
  dohandshake = dohandshake,
}
function TLS_mt:connect (host, port)
  self.socket = self.make ()
  if not self.socket:connect (host, port) then
    return false
  end
  self.socket = ssl.wrap (self.socket, {
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
  __index     = forward__index,
  dohandshake = dohandshake,
}
function STARTTLS_mt:connect (host, port)
  self.socket = self.make ()
  if not self.socket:connect (host, port) then
    print "connection failed"
    return nil, "connection failed"
  end
  self.socket:send ("EHLO cosy\r\n")
  repeat
    local line = self.socket:receive "*l"
  until line == nil
  self.socket:send "STARTTLS\r\n"
  self.socket:receive "*l"
  self.socket = ssl.wrap (self.socket, {
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
  local logger        = loader.logger
  local configuration = loader.configuration
  local domain        = configuration.server.root._
  local host          = configuration.smtp.host._
  local username      = configuration.smtp.username._
  local password      = configuration.smtp.password._
  local methods       = { configuration.smtp.method._ }
  if #methods == 0 then
    methods = {
      "STARTTLS",
      "TLS",
      "PLAINTEXT",
    }
  end
  local protocols = { configuration.smtp.protocol._ }
  if #protocols == 0 then
    protocols = {
      "TLS v1.2",
      "TLS v1.1",
      "TLS v1.0",
      "SSL v3",
      "SSL v2",
    }
  end
  local ports     = { configuration.smtp.port._ }
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
        logger.debug {
          _        = "smtp:discover",
          host     = host,
          port     = port,
          method   = method,
          protocol = protocol,
        }
        local ok, s = pcall (smtp.open, host, port, Tcp [method] (protocol, make_socket.sync))
        if ok then
          local ok = pcall (s.auth, s, username, password, s:greet (domain))
          if ok then
            configuration.smtp.port     = port
            configuration.smtp.method   = method
            configuration.smtp.protocol = protocol
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
  local i18n          = loader.i18n
  local configuration = loader.configuration
  local locale        = message.locale or configuration.locale.default._
  message.from   .locale = locale
  message.to     .locale = locale
  message.subject.locale = locale
  message.body   .locale = locale
  message.from    = i18n (message.from   )
  message.to      = i18n (message.to     )
  message.subject = i18n (message.subject)
  message.body    = i18n (message.body   )
  return smtp.send {
    from     = message.from:match (email_pattern),
    rcpt     = message.to  :match (email_pattern),
    source   = smtp.message {
      headers = {
        from    = message.from,
        to      = message.to,
        subject = message.subject,
      },
      body = message.body
    },
    user     = configuration.smtp.username._,
    password = configuration.smtp.password._,
    server   = configuration.smtp.host._,
    port     = configuration.smtp.port._,
    create   = Tcp [configuration.smtp.method._]
               (configuration.smtp.protocol._, make_socket.async),
  }
end

do
  local logger        = loader.logger
  local configuration = loader.configuration
  if not Email.discover () then
    logger.warning {
      _ = "smtp:not-available",
    }
  else
    logger.info {
      _        = "smtp:available",
      host     = configuration.smtp.host._,
      port     = configuration.smtp.port._,
      method   = configuration.smtp.method._,
      protocol = configuration.smtp.protocol._,
    }
  end
end

return Email