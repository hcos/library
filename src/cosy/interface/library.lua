local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
                      require "cosy.string"
local Methods       = require "cosy.methods"
local Coevas        = require "copas.ev"
Coevas:make_default ()
local Url           = require "socket.url"
local Websocket     = require "websocket"

local Library = {}

function Library.__index (library, key)
  return library._client [key]
end

function Library.client (url)
  local waiting   = {}
  local results   = {}
  local client    = {}
  local ws        = Websocket.client.copas {
    timeout = Configuration.client.timeout._,
  }
  Coevas.addthread (function ()
    ws:connect (url, "cosy")
  end)
  local function react ()
    while true do
      local message = ws:receive ()
      if not message then
        return
      end
      message = Platform.value.decode (message)
      local identifier = message.identifier
      results [identifier] = message
      Coevas.wakeup (waiting [identifier])
    end
  end
  function client.loop ()
    Coevas.addthread (react)
    Coevas.loop ()
  end
  for operation in pairs (Methods) do
    client [operation] = function (parameters)
      local result  = nil
      local coreact = Coevas.addthread (react)
      Coevas.addthread (function ()
        local co = coroutine.running ()
        local identifier = #waiting+1
        waiting [identifier] = co
        results [identifier] = nil
        ws:send (Platform.value.expression {
          identifier = identifier,
          operation  = operation,
          parameters = parameters or {},
        })
        Coevas.sleep (Configuration.client.timeout._)
        result = results [identifier]
        waiting [identifier] = nil
        results [identifier] = nil
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
        error (result.response)
      end
    end
  end
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
    password = Platform.digest (password)
    password = Platform.encryption.encode ("%{username}:%{password}" % {
      username = username,
      password = password,
    }, password)
    client.authenticate {
      username = username,
      password = password,
    }
  end
  return setmetatable ({
    _client = client,
  }, Library)
end

do
  local lib = Library.connect "http://127.0.0.1:8080/"
  local start = require "socket".gettime ()
  local n     = 10000
  for i = 1, n do
    local _ = Platform.value.expression (lib.information ())
  end
  local finish = require "socket".gettime ()
  print (math.floor (n / (finish - start)))
end