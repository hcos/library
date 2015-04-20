local hotswap = require "hotswap"

if _G.js then
  local js = _G.js
  return js.global.Date.now
else
  local socket = hotswap "socket"
  return socket.gettime
end
