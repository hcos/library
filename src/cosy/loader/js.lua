if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local loader   = {}
local modules  = setmetatable ({}, { __mode = "kv" })

loader.request   = function (url)
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
  result, err = loader.request (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)
loader.require = require
loader.load    = function (name)
  if modules [name] then
    return modules [name]
  end
  local module   = loader.require (name) (loader) or true
  modules [name] = module
  return module
end

loader.hotswap   = loader.require "hotswap".new {}
loader.coroutine = loader.require "coroutine.make" ()
_G.coroutine     = loader.coroutine

loader.scheduler = {}
function loader.scheduler.running ()
  return coroutine.running ()
end
function loader.scheduler.sleep (time)
  print ("sleep", coroutine.running (), time)
  time = time or -math.huge
  local co = coroutine.running ()
  if time > 0 then
    _G.window:setTimeout (function ()
      local ok, err = coroutine.resume (co)
      if not ok then
        _G.window.console:log (err)
      end
    end, time * 1000)
  end
  if time ~= 0 then
    coroutine.yield ()
  end
end
function loader.scheduler.wakeup (co)
  print ("wakeup", co)
  local ok, err = coroutine.resume (co)
  if not ok then
    _G.window.console:log (err)
  end
end
function loader.scheduler.addthread (f, ...)
  f (...)
end
function loader.scheduler.loop ()
end

loader.load "cosy.string"
return loader
