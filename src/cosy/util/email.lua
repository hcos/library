local Email = {}

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
local _             = require "cosy.util.string"

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
  self.socket:send ("EHLO " .. Configuration.server.root .. "\r\n")
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
  self.socket:send ("EHLO " .. Configuration.server.root .. "\r\n")
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
  local domain    = Configuration.server.root
  local host      = Configuration.smtp.host
  local username  = Configuration.smtp.username
  local password  = Configuration.smtp.password
  local methods   = { Configuration.smtp.method }
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

local function extract (source, t)
  if source == nil then
    source = {}
  elseif type (source) == "string" then
    source = { source }
  end
  for _, s in ipairs (source) do
    t [#t + 1] = s:match (email_pattern)
  end
end

function Email.send (message)
  local from       = {}
  local recipients = {}
  extract (message.from, from)
  extract (message.to  , recipients)
  extract (message.cc  , recipients)
  extract (message.bcc , recipients)
  local make = Platform.scheduler.IN_THREAD
           and make_socket.async
            or make_socket.sync
  return smtp.send {
    from     = from [1],
    rcpt     = recipients,
    source   = smtp.message {
      headers = {
        from    = message.from,
        to      = message.to,
        cc      = message.cc,
        subject = message.subject,
      },
      body = message.body
    },
    user     = Configuration.smtp.username,
    password = Configuration.smtp.password,
    server   = Configuration.smtp.host,
    port     = Configuration.smtp.port,
    create   = Tcp [Configuration.smtp.method] (Configuration.smtp.protocol, make),
  }
end

return Email