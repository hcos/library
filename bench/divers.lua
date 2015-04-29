local Platform      = require "cosy.platform"
local ev            = require "ev"
local websocket     = require "websocket"

local nb_threads    = 100
local nb_iterations = 500

--local running  = 0
local opened   = {}
local closed   = 0
local sent     = 0
local received = 0

for _ = 1, nb_threads  do
  local client = websocket.client.ev {
    timeout = 10
  }
  local id = 1
  client:on_open (function ()
    opened [#opened+1] = client
    if #opened == nb_threads then
      for i = 1, #opened do
        opened [i]:send (Platform.table.encode {
          identifier = tostring (1),
          operation  = "information",
          parameters = {},
        })
        sent = sent + 1
      end
    end
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
      sent = sent + 1
    end
  end)
  client:on_close (function ()
    closed = closed + 1
    if closed == nb_threads then
      print ("sent", sent * 100 / (nb_threads * nb_iterations)        , "%",
             "received", received * 100 / (nb_threads * nb_iterations), "%")
      os.exit (0)
    end
  end)
  client:connect ("ws://127.0.0.1:8080", "cosy")
end

local statistics = ev.Timer.new (function ()
  print ("sent", sent * 100 / (nb_threads * nb_iterations)        , "%",
         "received", received * 100 / (nb_threads * nb_iterations), "%")
end, 1, 1)

statistics:start (ev.Loop.default)

ev.Loop.default:loop ()