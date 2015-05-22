local Configuration = require "cosy.configuration"
local Value         = require "cosy.value"

local Library = {}
local Client  = {}

if _G.js then
  function Client.__index (client, operation)
    return function (parameters, try_only)
     --js.global.console:log ("client waiting" .. tostring (client._waiting))
      local identifier = #client._waiting+1
      client._ws:send (Value.expression {
        identifier = identifier,
        operation  = operation,
        parameters = parameters or {},
        try_only = try_only,
      })
       js.global.console:log ("wait: index")
       client._waiting[identifier] = coroutine.running ()
      local result = coroutine.yield ()
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
    local co = coroutine.running ()
    local client = setmetatable ({
      _results = {},
      _waiting = {},
    }, Client)
    client._ws = _G.js.new (_G.js.global.WebSocket, url, "cosy")
    client._ws.onopen    = function (ws)
      js.global.console:log ("connect")
      coroutine.resume (co, true)
    end
    client._ws.onclose   = function (ws,event)
      js.global.console:log ("disconnect")
      coroutine.resume (co, nil, event.reason)
    end
    client._ws.onmessage = function (ws,event)
      local message    = Value.decode (event.data)
      local identifier = message.identifier
      if identifier then
      local co = client._waiting[identifier]
      assert(co)
      client._waiting[identifier] = nil
        coroutine.resume (co, message)
      else
        client.on_update ()
      end
    end
    js.global.console:log ("wait: client")
    local ok, err = coroutine.yield ()
    if not ok then
      error (err)
    end
    return client
  end

  function Library.connect (url)
    local parser   = _G.js.global.document:createElement "a";
    parser.href    = url;
    local protocol = parser.protocol
    local hostname = parser.hostname
    local port     = parser.port
    local username = parser.username
    local password = parser.password
    local path     = parser.pathname
    if protocol:sub (-1) == ":" then
      protocol = protocol:sub (1, #protocol-1)
    end
    if path:sub (1) == "/" then
      path = path:sub (2)
    end
    local client = Library.client ("ws://%{hostname}:%{port}/ws" % {
      hostname = hostname,
      port     = port,
    })
    return client
  end

else

  local Scheduler     = require "cosy.scheduler"
  local Url           = require "socket.url"
  local Websocket     = require "websocket"

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
    return client
  end
end

return Library
