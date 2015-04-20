local loader        = require "cosy.loader"
local hotswap       = loader.hotswap
local Coevas        = hotswap "copas.ev"
Coevas:make_default ()
local Url           = hotswap "socket.url"
local Websocket     = hotswap "websocket"

local Library = {}
local Client  = {}

function Client.react (client)
  while true do
    local message = client._ws:receive ()
    if not message then
      return
    end
    message = loader.value.decode (message)
    local identifier = message.identifier
    if identifier then
      client._results [identifier] = message
      Coevas.wakeup (client._waiting [identifier])
    else
      client.on_update ()
    end
  end
end

function Client.loop (client)
  Coevas.addthread (Client.react, client)
  Coevas.loop ()
end

function Client.__index (client, operation)
  return function (parameters)
    local result  = nil
    local coreact = Coevas.addthread (Client.react, client)
    Coevas.addthread (function ()
      local co = coroutine.running ()
      local identifier = #client._waiting+1
      client._waiting [identifier] = co
      client._results [identifier] = nil
      client._ws:send (loader.value.expression {
        identifier = identifier,
        operation  = operation,
        parameters = parameters or {},
      })
      Coevas.sleep (loader.configuration.client.timeout._)
      result = client._results [identifier]
      client._waiting [identifier] = nil
      client._results [identifier] = nil
      Coevas.kill (coreact)
    end)
    Coevas.loop ()
    if result == nil then
      error {
        _ = "timeout",
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
    timeout = loader.configuration.client.timeout._,
  }
  Coevas.addthread (function ()
    client._ws:connect (url, "cosy")
  end)
  Coevas.loop ()
  return client
end

function Library.connect (url)
  local parsed   = Url.parse (url)
  local host     = parsed.host
  local port     = parsed.port
  local username = parsed.user
  local password = parsed.password
  local client   = Library.client ("ws://%{host}:%{port}/" % {
    host = host,
    port = port,
  })
  if username and password then
    password = loader.digest ("%{username}:%{password}" % {
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