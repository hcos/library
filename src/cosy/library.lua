local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"

local Library = {}
local Client  = {}

local function patch (client)
  function client.authenticate (parameters, try_only)
    parameters.password = Digest ("%{username}:%{password}" % {
      username = parameters.username,
      password = parameters.password,
    })
    client.username = parameters.username
    client.password = parameters.password
    return Client.__index (client, "authenticate") (parameters, try_only)
  end
  function client.create_user (parameters, try_only)
    parameters.password = Digest ("%{username}:%{password}" % {
      username = parameters.username,
      password = parameters.password,
    })
    client.username = parameters.username
    client.password = parameters.password
    return Client.__index (client, "create_user") (parameters, try_only)
  end
  return client
end

local function threadof (f, ...)
  if Scheduler._running then
    f (...)
  else
    Scheduler.addthread (f, ...)
    Scheduler.loop ()
  end
end

function Client.__index (client, operation)
  assert (client._status == "opened")
  return function (parameters, try_only)
    local result
    local function f ()
      local co         = coroutine.running ()
      local identifier = #client._waiting + 1
      client._waiting [identifier] = co
      client._results [identifier] = nil
      client._ws:send (Value.expression {
        identifier = identifier,
        operation  = operation,
        parameters = parameters or {},
        try_only   = try_only,
      })
      Scheduler.sleep (Configuration.library.timeout._)
      result = client._results [identifier]
      client._waiting [identifier] = nil
      client._results [identifier] = nil
    end
    threadof (f)
    if result == nil then
      return nil, {
        _ = "client:timeout",
      }
    elseif result.success then
      return result.response or true
    else
      return nil, result.error
    end
  end
end

function Library.client (t)
  local client = setmetatable ({
    _results = {},
    _waiting = {},
  }, Client)
  client.host     = t.host     or false
  client.port     = t.port     or 80
  client.username = t.username or false
  client.password = t.password or false
  client._retry   = 0
  local url = "ws://%{host}:%{port}/ws" % {
    host = client.host,
    port = client.port,
  }
  if _G.js then
    client._ws = _G.js.new (_G.js.global.WebSocket, url, "cosy")
  else
    local Websocket = require "websocket"
    client._ws = Websocket.client.ev {
      timeout = Configuration.library.timeout._,
      loop    = Scheduler._loop,
    }
  end
  client._connect       = function ()
    client._status = "closed"
    client._ws:connect (url, "cosy")
    client._co = coroutine.running ()
    Scheduler.sleep (-math.huge)
  end
  client._ws.onopen     = function ()
    client._status = "opened"
    Scheduler.wakeup (client._co)
  end
  client._ws.onclose    = function ()
    client._status = "closed"
    client._retry  = client._retry + 1
    if  Configuration.library.retry._
    and client._retry < Configuration.library.retry._ then
      threadof (client._connect)
    end
  end
  client._ws.onmessage  = function (_, event)
    local message 
    if _G.js then
      message = event.data
    else
      message = event
    end
    message = Value.decode (message)
    local identifier = message.identifier
    if identifier then
      client._results [identifier] = message
      Scheduler.wakeup (client._waiting [identifier])
    end
  end
  client._ws.onerror    = function (_, err)
    client._status = "closed"
    client._err    = err
    Scheduler.wakeup (client._co)
  end
  if not _G.js then
    client._ws:on_open    (client._ws.onopen   )
    client._ws:on_close   (client._ws.onclose  )
    client._ws:on_message (client._ws.onmessage)
    client._ws:on_error   (client._ws.onerror  )
  end
  if _G.js then
    client._co = coroutine.running ()
    Scheduler.sleep (-math.huge)
  else
    threadof (client._connect)
  end
  if      client._status == "opened" then
    return patch (client)
  elseif client._status == "closed" then
    return nil, client._err
  else
    assert (false)
  end
end

if _G.js then
  function Library.connect (url)
    local parser   = _G.js.global.document:createElement "a";
    parser.href    = url;
    return Library.client {
      host     = parser.hostname,
      port     = parser.port,
      username = parser.username,
      password = parser.password,
    }
  end
else
  local Url = require "socket.url"
  function Library.connect (url)
    local parsed = Url.parse (url)
    return Library.client {
      host     = parsed.host,
      port     = parsed.port,
      username = parsed.user,
      password = parsed.password,
    }
  end
end

return Library
