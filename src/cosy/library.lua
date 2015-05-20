local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Scheduler     = require "cosy.scheduler"
local Value         = require "cosy.value"
local Url           = require "socket.url"
local Websocket     = require "websocket"

local Library = {}
local Client  = {}

function Client.react (client)
  while true do
    local message = client._ws:receive ()
    if not message then
      return
    end
    message = Value.decode (message)
    local identifier = message.identifier
    if identifier then
      client._results [identifier] = message
      Scheduler.wakeup (client._waiting [identifier])
    else
      client.on_update ()
    end
  end
end

function Client.loop (client)
  Scheduler.addthread (Client.react, client)
  Scheduler.loop ()
end

function Client.__index (client, operation)
  return function (parameters, try_only)
    local result  = nil
    local coreact = Scheduler.addthread (Client.react, client)
    Scheduler.addthread (function ()
      local co = coroutine.running ()
      local identifier = #client._waiting+1
      client._waiting [identifier] = co
      client._results [identifier] = nil
      client._ws:send (Value.expression {
        identifier = identifier,
        operation  = operation,
        parameters = parameters or {},
        try_only   = try_only,
      })
      Scheduler.sleep (Configuration.client.timeout._)
      result = client._results [identifier]
      client._waiting [identifier] = nil
      client._results [identifier] = nil
      Scheduler.kill (coreact)
    end)
    Scheduler.loop ()
    if result == nil then
      error {
        _ = "client:timeout",
      }
    elseif result.success then
      return result.response
    else
      error (result.error)
    end
  end
end

function Library.client (url)
  local client = setmetatable ({
    _waiting = {},
    _results = {},
    _react   = nil,
  }, Client)
  client._ws = Websocket.client.copas {
    timeout = Configuration.client.timeout._,
  }
  Scheduler.addthread (function ()
    client._ws:connect (url, "cosy")
  end)
  Scheduler.loop ()
  return client
end

function Library.connect (url)
  local parsed   = Url.parse (url)
  local host     = parsed.host
  local port     = parsed.port
  local username = parsed.user
  local password = parsed.password
  local client   = Library.client ("ws://%{host}:%{port}/ws" % {
    host = host,
    port = port,
  })
  if username and password then
    password = Digest ("%{username}:%{password}" % {
      username = username,
      password = password,
    })
    client.authenticate {
      username = username,
      password = password,
    }
  end
  return client
end

return Library