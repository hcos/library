-- All lua code is executed within a coroutine.
local loader = require "cosy.loader"
loader.hotswap "cosy.string"
local Library = {}
local Client  = {}

function Client.__index (client, operation)
  return function (parameters)
    local identifier = #client._waiting+1
    client._ws:send (loader.value.expression {
      identifier = identifier,
      operation  = operation,
      parameters = parameters or {},
    })
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
  }, Client)
  client._ws = _G.js.new (_G.js.global.WebSocket, url, "cosy")
  client._ws.onopen    = function ()
    coroutine.resume (co, true)
  end
  client._ws.onclose   = function (event)
    coroutine.resume (co, nil, event.reason)
  end
  client._ws.onmessage = function (event)
    local message    = loader.value.decode (event.data)
    local identifier = message.identifier
    if identifier then
      coroutine.resume (co, message)
    else
      client.on_update ()
    end
  end
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
  local client = Library.client ("%{protocol}://%{hostname}:%{port}/%{path}" % {
    protocol = protocol,
    hostname = hostname,
    port     = port,
    path     = path,
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