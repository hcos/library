local Platform      = require "cosy.platform"
local ev            = require "ev"
local websocket     = require "websocket"

local nb_threads    = 500
local nb_iterations = 50

--local running  = 0
local closed   = 0
local received = 0

for _ = 1, nb_threads  do
  local client = websocket.client.ev {
    timeout = 2
  }
--  running = running + 1
  local id = 1
  client:on_open (function ()
    client:send (Platform.table.encode {
      identifier = tostring (id),
      operation  = "information",
      parameters = {},
    })
  end)
  client:on_message (function (ws, message)
    received = received + 1
    if id == nb_iterations then
      client:close ()
    else
      id = id + 1
      client:send (Platform.table.encode {
        identifier = tostring (id),
        operation  = "information",
        parameters = {},
      })
    --[[
      client:send (Platform.table.encode {
        identifier = tostring (id),
        operation  = "authenticate",
        parameters = {
          username = "toto",
          password = "grouik",
        },
      })
    --]]
    end
  end)
  client:on_close (function ()
    closed = closed + 1
    if closed == nb_threads then
      print ("received", received * 100 / (nb_threads * nb_iterations), "%")
      os.exit (0)
    end
  end)
  client:connect ("ws://127.0.0.1:8080", "cosy")
end

local statistics = ev.Timer.new (function ()
  print ("received", received * 100 / (nb_threads * nb_iterations), "%")
end, 1, 1)

statistics:start (ev.Loop.default)

ev.Loop.default:loop ()