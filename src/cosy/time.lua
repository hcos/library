local loader  = require "cosy.loader"

if _G.js then
  local js = _G.js
  return js.global.Date.now
else
  local socket = loader "socket"
  return socket.gettime
end
