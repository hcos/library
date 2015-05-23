local Loader = require "cosy.loader"

if _G.js then
  Loader.scheduler = {}
  function Loader.scheduler.sleep (time)
    time = time or -math.huge
    local co = coroutine.running ()
    if time > 0 then
      _G.js.global:setTimeout (function ()
        coroutine.resume (co)
      end, time * 1000)
    end
    if time ~= 0 then
      coroutine.yield ()
    end
  end
  function Loader.scheduler.wakeup (co)
    coroutine.resume (co)
  end
  function Loader.scheduler.addthread (f, ...)
    f (...)
  end
  function Loader.scheduler.loop ()
  end
end

return Loader.scheduler