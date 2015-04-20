local loader  = require "cosy.loader"
local hotswap = loader.hotswap

if _G.js then
  error "Not available"
end

return function ()
  local socket    = hotswap "socket"
  local scheduler = loader.scheduler
  local skt       = socket.tcp ()
  local result    = scheduler.wrap (skt)
  return result
end
