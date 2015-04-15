-- This module is a copy/paste of
-- https://github.com/lipp/lua-websockets/blob/master/src/websocket/server_copas.lua
-- because i found no other way to do it.
local handshake = require "websocket.handshake"
local sync      = require "websocket.sync"

--local clients   = {}

local function websocket (context)
  context.websocket.handler (context)
end

return function (context)
  local raw =  {}
  raw [#raw+1] = "%{method} %{uri} %{protocol}" % context.request
  for key, value in pairs (context.request.headers) do
    raw [#raw+1] = "%{key}: %{value}" % {
      key   = key,
      value = value,
    }
  end
  raw [#raw+1] = ""
  local request   = table.concat (raw, "\r\n")
  local protocols = context.websocket.protocols
  local answer, protocol = handshake.accept_upgrade (request, protocols)
  if not answer then
    context.response.status  = 400
    context.response.message = "Bad Request"
    return
  end
  context.response.status  = 101
  context.response.message = "Switching Protocols"
  context.response.headers ["upgrade"   ] = "websocket"
  context.response.headers ["connection"] = context.request.headers ["connection"]
  context.response.headers ["sec-websocket-protocol"] = protocol
  context.response.headers ["sec-websocket-accept"  ] =
    handshake.sec_websocket_accept (context.request.headers ["sec-websocket-key"])
  local client = {
    state     = "OPEN",
    is_server = true,
  }
  client.sock_send    = function (_, ...)
    return context.socket:send (...)
  end
  client.sock_receive = function (_, ...)
    return context.socket:receive (...)
  end
  client.sock_close   = function (_)
    context.socket:shutdown ()
    context.socket:close ()
  end
  client = sync.extend (client)
  client.on_close     = function (_)
  end
  context.websocket.client   = client
  context.websocket.protocol = protocol or true
  context.http.handler       = function () end
  context.next               = websocket
end