-- See https://github.com/lipp/lua-websockets/blob/master/src/websocket/handshake.lua
local handshake = require "websocket.handshake"

local Upgrade = {}

function Upgrade.request (context)
  local raw =  {}
  raw [#raw+1] = "%{method} %{uri} %{protocol}" % context.request
  for key, value in pairs (context.request.headers) do
    raw [#raw+1] = "%{key}: %{value}" % {
      key   = key,
      value = value,
    }
  end
  raw [#raw+1] = ""
  local request = table.concat (raw, "\r\n")
  local answer, protocol = handshake.accept_upgrade (request, context.ws_protocols)
  if not answer then
    context.response.status  = 400
    context.response.message = "Bad Request"
    return
  end
  context.response.status  = 101
  context.response.message = "Switching Protocols"
  context.response.headers ["upgrade"] =
    "websocket"
  context.response.headers ["connection"] =
    context.request.headers ["connection"]
  context.response.headers ["sec-websocket-accept"] =
    handshake.sec_websocket_accept (context.request.headers ["sec-websocket-key"])
  context.response.headers ["sec-websocket-protocol"] =
    protocol
  context.ws_protocol = protocol or true
  context.next = require "cosy.websocket" .new (context)
end

function Upgrade.response ()
end

return Upgrade