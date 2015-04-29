local copas         = require "copas"
local socket        = require "socket"
local websocket     = require "websocket"

local server = websocket.server.copas.listen
{
  port = 8080,
  protocols = {
    cosy = function (ws)
      while true do
        local message = ws:receive ()
        if message then
          ws:send [[{identifier=1,response={name="saucisse"},success=true}]]
        else
          ws:close ()
          return
        end
      end
    end,
  },
}

copas.loop ()