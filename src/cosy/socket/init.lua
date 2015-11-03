if _G.js then
  error "Not available"
end

return function (loader)

  local Scheduler = loader.load "cosy.scheduler"
  local Socket    = loader.require "socket"

  return function ()
    return Scheduler.wrap (Socket.tcp ())
  end

end
