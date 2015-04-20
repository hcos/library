local hotswap = require "hotswap"

if _G.js then
  error "Not available"
end

return function ()
  local socket    = hotswap "socket"
  local scheduler = hotswap "cosy.platform.scheduler"
  local skt       = socket.tcp ()
  local result    = scheduler.wrap (skt)
  return result
end
