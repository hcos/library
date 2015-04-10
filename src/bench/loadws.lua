local Platform      = require "cosy.platform"
local Copas         = require "copas.ev"
Copas:make_default ()
local socket        = require "socket"
local websocket     = require "websocket"

local nb_threads    = 500
local nb_iterations = 100

--local running  = 0
local opened   = {}
local closed   = 0
local sent     = 0
local received = 0

local start = socket.gettime ()
for thread = 1, nb_threads  do
  Copas.addthread (function ()
    local client = websocket.client.copas {
      timeout = 10
    }
    client:connect ("ws://127.0.0.1:8080", "cosy")
    opened [#opened+1] = coroutine.running ()
    if #opened ~= nb_threads then
      Copas.sleep (-math.huge)
    else
      start = socket.gettime ()
      for i = 1, #opened do
        Copas.wakeup (opened [i])
      end
    end
    for id = 1, nb_iterations do
--      Copas.sleep (0.1)
      client:send (Platform.table.encode {
        identifier = tostring (id),
        operation  = "information",
        parameters = {},
      })
      sent = sent + 1
      local message = client:receive ()
      received = received + 1
    end
    client:close ()
    closed = closed + 1
    if closed == nb_threads then
      print ("sent", sent * 100 / (nb_threads * nb_iterations)        , "%",
             "received", received * 100 / (nb_threads * nb_iterations), "%",
             "per second", math.floor (sent / (socket.gettime () - start)))
      os.exit (0)
    end
  end)
end

Copas.addthread (function ()
  while true do
    Copas.sleep (1)
    print ("sent", sent * 100 / (nb_threads * nb_iterations)        , "%",
           "received", received * 100 / (nb_threads * nb_iterations), "%",
           "per second", math.floor (sent / (socket.gettime () - start)))
  end
end)

Copas.loop ()