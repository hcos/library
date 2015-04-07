local sync = require "websocket.sync"

local WebSocket = {}
local clients = {}

-- https://github.com/lipp/lua-websockets/blob/master/src/websocket/server_copas.lua
local make_client = function (socket, protocol)
  local result = {
    state     = "OPEN",
    is_server = true,
  }

  if not clients [protocol] then
    clients [protocol] = {}
  end
  clients [protocol] [result] = true

  result.sock_send = function (_, ...)
    return socket:send (...)
  end
  
  result.sock_receive = function (_, ...)
    return socket:receive (...)
  end
  
  result.sock_close = function (_)
    socket:shutdown ()
    socket:close ()
  end
  
  result = sync.extend (result)
  
  result.on_close = function (self)
    clients [protocol] [self] = nil
  end
  
  result.broadcast = function (self, ...)
    for client in pairs (clients [protocol]) do
      if client ~= self then
        client:send (...)
      end
    end
    self:send (...)
  end
  
  return result
end

function WebSocket.new (context)
  return setmetatable (context, WebSocket)
end

function WebSocket.__call (context)
  context.ws_client = make_client (context.socket, context.ws_protocol)
  return context:ws_handler ()
end

function WebSocket.__tostring ()
  return "WebSocket"
end

return WebSocket