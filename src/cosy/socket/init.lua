if _G.js then
  error "Not available"
end

local Scheduler = require "cosy.scheduler"
local Socket    = require "socket"

return function ()
  return Scheduler.wrap (Socket.tcp ())
end
