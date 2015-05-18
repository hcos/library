local loader  = require "cosy.loader"

if _G.js then
  error "Not available"
end

return function ()
  local socket    = loader "socket"
  local scheduler = loader.scheduler
  local skt       = socket.tcp ()
  local result    = scheduler.wrap (skt)
  return result
end
