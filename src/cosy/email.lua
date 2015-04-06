local Email = {}

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
                      require "cosy.string"

local socket        = require "socket"
local smtp          = require "socket.smtp"
local ssl           = require "ssl"

-- First case: detection, using blocking sockets
-- Second case: email sending, using non-blocking sockets

local make_socket = {}

function make_socket.sync ()
  local result = socket.tcp ()
  result:settimeout (1)
  result:setoption ("keepalive", true)
  result:setoption ("reuseaddr", true)
  result:setoption ("tcp-nodelay", true)
  return result
end

function make_socket.async ()
  local result = Platform.scheduler:wrap (socket.tcp ())
  result:settimeout (0)
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

local function dohandshake (self)
  while true do
    local ok, err = self.socket:dohandshake ()
    if ok then
      return true
    elseif err == "wantread"
        or err == "wantwrite"
        or err == "timeout" then
    -- loop
    else
      error (err)
    end
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
  return self:dohandshake ()
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
    print "connect failed"
    return false
  end
  self.socket:receive "*l"
  self.socket:send ("EHLO " .. Configuration.server.root._ .. "\r\n")
  repeat
    local line = self.socket:receive "*l"
  until line == nil
  self.socket:send "STARTTLS\r\n"
  self.socket:receive "*l"
  self.socket = ssl.wrap (self.socket, {
    mode     = "client",
    protocol = tls_alias [self.protocol],
  })
  local result = self:dohandshake ()
  self.socket:send ("EHLO " .. Configuration.server.root._ .. "\r\n")
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
  local domain    = Configuration.server.root._
  local host      = Configuration.smtp.host._
  local username  = Configuration.smtp.username._
  local password  = Configuration.smtp.password._
  local methods   = { Configuration.smtp.method._ }
  if #methods == 0 then
    methods = {
      "STARTTLS",
      "TLS",
      "PLAINTEXT",
    }
  end
  local protocols = { Configuration.smtp.protocol._ }
  if #protocols == 0 then
    protocols = {
      "TLS v1.2",
      "TLS v1.1",
      "TLS v1.0",
      "SSL v3",
      "SSL v2",
    }
  end
  local ports     = { Configuration.smtp.port._ }
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
        Platform.logger.debug ("Discovering SMTP on ${host}:${port} using ${method} (encrypted with ${protocol})" % {
          host     = host,
          port     = port,
          method   = method,
          protocol = protocol,
        })
        local ok, s = pcall (smtp.open, host, port, Tcp [method] (protocol, make_socket.sync))
        if ok then
          local ok = pcall (s.auth, s, username, password, s:greet (domain))
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
  local locale     = message.locale or Configuration.locale.default._
  message.from   .locale = locale
  message.to     .locale = locale
  message.subject.locale = locale
  message.body   .locale = locale
  message.from    = Platform.i18n.translate (message.from    [1], message.from   )
  message.to      = Platform.i18n.translate (message.to      [1], message.to     )
  message.subject = Platform.i18n.translate (message.subject [1], message.subject)
  message.body    = Platform.i18n.translate (message.body    [1], message.body   )
  local make = Platform.scheduler.IN_THREAD
           and make_socket.async
            or make_socket.sync
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
    user     = Configuration.smtp.username._,
    password = Configuration.smtp.password._,
    server   = Configuration.smtp.host._,
    port     = Configuration.smtp.port._,
    create   = Tcp [Configuration.smtp.method._] (Configuration.smtp.protocol._, make),
  }
end

return Email