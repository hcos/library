if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

return function (t)
  t = t or {}
  local loader   = {}
  local modules  = setmetatable ({}, { __mode = "kv" })
  loader.hotswap = t.hotswap
                or require "hotswap".new {}
  loader.require = function (name)
    local back = _G.require
    _G.require = loader.hotswap.require
    local result = loader.hotswap.require (name)
    _G.require = back
    return result
  end
  loader.load    = function (name)
    if modules [name] then
      return modules [name]
    end
    local module   = loader.require (name) (loader) or true
    modules [name] = module
    return module
  end
  loader.logto     = t.logto
  loader.coroutine = t.coroutine
                  or loader.require "coroutine.make" ()
  _G.coroutine     = loader.coroutine
  loader.scheduler = t.scheduler
                  or loader.require "copas.ev"
  loader.request   = t.request
                  or loader.require "socket.http".request
  loader.load "cosy.string"
  loader.hotswap.preload ["websocket.bit"         ] = function ()
    return loader.require "cosy.loader.patches.bit"
  end
  loader.hotswap.preload ["websocket.server_copas"] = function ()
    return loader.require "cosy.loader.patches.server_copas"
  end
  return loader
end
