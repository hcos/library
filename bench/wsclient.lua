local copas         = require "copas"
local socket        = require "socket"
local websocket     = require "websocket"

copas.addthread (function ()
  local client = websocket.client.copas {
    timeout = 10
  }
  client:connect ("ws://127.0.0.1:8080", "cosy")
  client:send ([[{
    identifier = 1,
    operation  = "information",
    parameters = {},
  }]])
  print (client:receive ())
  client:close ()
end)

copas.loop ()