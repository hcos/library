local Configuration = require "cosy.configuration"
local CSocket       = require "cosy.socket"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Scheduler     = require "cosy.scheduler"
local Socket        = require "socket"
local Smtp          = require "socket.smtp"
local Ssl           = require "ssl"
if not Ssl then
  Ssl = _G.ssl
end

local i18n   = I18n.load (require "cosy.email-i18n")
i18n._locale = Configuration.locale._

if _G.js then
  error "Not available"
end

local Email = {}

-- First case: detection, using blocking sockets
-- Second case: email sending, using non-blocking sockets

local make_socket = {}

function make_socket.sync ()
  local result = Socket.tcp ()
  result:settimeout (Configuration.smtp.timeout._)
  result:setoption ("keepalive", true)
  result:setoption ("reuseaddr", true)
  result:setoption ("tcp-nodelay", true)
  return result
end

function make_socket.async ()
  local result = CSocket ()
  result:settimeout (Configuration.smtp.timeout._)
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
  local domain        = Configuration.server.root._
  local host          = Configuration.smtp.host._
  local username      = Configuration.smtp.username._
  local password      = Configuration.smtp.password._
  local methods       = { Configuration.smtp.method._ }
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
        Logger.debug {
          _        = i18n ["smtp:discover"],
          host     = host,
          port     = port,
          method   = method,
          protocol = protocol,
        }
        local ok, s = pcall (Smtp.open, host, port, Tcp [method] (protocol, make_socket.sync))
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
    local locale    = message.locale or Configuration.locale.default._
    local si18n     = I18n.new (locale)
    message.from    = si18n (message.from   )
    message.to      = si18n (message.to     )
    message.subject = si18n (message.subject)
    message.body    = si18n (message.body   )
    Smtp.send {
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
      user     = Configuration.smtp.username._,
      password = Configuration.smtp.password._,
      server   = Configuration.smtp.host._,
      port     = Configuration.smtp.port._,
      create   = Tcp [Configuration.smtp.method._] (Configuration.smtp.protocol._, make_socket.async),
    }
  end)
end

do
  if not Email.discover () then
    Logger.warning {
      _ = i18n ["smtp:not-available"],
    }
  else
    Logger.info {
      _        = i18n ["smtp:available"],
      host     = Configuration.smtp.host._,
      port     = Configuration.smtp.port._,
      method   = Configuration.smtp.method._,
      protocol = Configuration.smtp.protocol._,
    }
  end
end

return Email