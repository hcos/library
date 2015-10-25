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
  loader.require = loader.hotswap.require
  loader.load    = function (name)
    if modules [name] then
      return modules [name]
    end
    local module   = loader.require (name) (loader) or true
    modules [name] = module
    return module
  end
  loader.logto     = t.logto
  loader.coroutine = loader.require "coroutine.make" ()
  loader.scheduler = t.scheduler
                  or loader.require "copas.ev"
  loader.request   = t.request
                  or loader.require "socket.http".request
  loader.load "cosy.string"
  return loader
end
