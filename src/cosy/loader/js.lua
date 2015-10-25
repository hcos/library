if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

package.preload ["cosy.loader"] = function ()
  return Loader
end

Loader.loadhttp = function (url)
  local request = _G.js.new (_G.window.XMLHttpRequest)
  request:open ("GET", url, false)
  request:send (nil)
  if request.status == 200 then
    return request.responseText, request.status
  else
    return nil , request.status
  end
end

table.insert (package.searchers, 2, function (name)
  local url = "/lua/" .. name
  local result, err
  result, err = Loader.loadhttp (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)

Loader.hotswap = require "hotswap" .new {}

Loader.scheduler = {}
function Loader.scheduler.sleep (time)
  time = time or -math.huge
  local co = coroutine.running ()
  if time > 0 then
    _G.window:setTimeout (function ()
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

                 require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
