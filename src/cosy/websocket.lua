-- This module is a copy/paste of
-- https://github.com/lipp/lua-websockets/blob/master/src/websocket/server_copas.lua
-- because i found no other way to 


local sync = require "websocket.sync"

local WebSocket = {}

local clients   = {}

function WebSocket.new (context)
  return setmetatable (context, WebSocket)
end

function WebSocket.__call (context)
  local client = {
    state     = "OPEN",
    is_server = true,
  }
  if not clients [context.ws_protocol] then
    clients [context.ws_protocol] = {}
  end
  clients [context.ws_protocol] [client] = true
  client.sock_send = function (_, ...)
    return context.socket:send (...)
  end
  client.sock_receive = function (_, ...)
    return context.socket:receive (...)
  end
  client.sock_close = function (_)
    context.socket:shutdown ()
    context.socket:close ()
  end
  client = sync.extend (client)
  client.on_close = function (_)
    clients [context.ws_protocol] [client] = nil
  end
  client.broadcast = function (_, ...)
    for c in pairs (clients [context.ws_protocol]) do
      if c ~= client then
        c:send (...)
      end
    end
    client:send (...)
  end
  context.ws_client = client
  return context:ws_handler ()
end

function WebSocket.__tostring ()
  return "WebSocket"
end

return WebSocket