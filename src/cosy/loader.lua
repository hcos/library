local version = tonumber (_VERSION:match "Lua%s*(%d%.%d)")
if version < 5.1
or (version == 5.1 and type (_G.jit) ~= "table") then
  error "Cosy requires Luajit >= 2 or Lua >= 5.2 to run."
end

local Loader = {}

Loader.__index = function (loader, key)
  return loader.hotswap:require ("cosy." .. tostring (key))
end
Loader.__call  = function (loader, key)
  return loader.hotswap:require (key)
end

local loader = setmetatable ({}, Loader)

if _G.js then
  _G.loadhttp = function (url)
    local co = coroutine.running ()
    local request = _G.js.new (_G.js.global.XMLHttpRequest)
    request:open ("GET", url, true)
    request.onreadystatechange = function (event)
      if request.readyState == 4 then
        if request.status == 200 then
          coroutine.resume (co, request.responseText)
        else
          coroutine.resume (co, nil, event.target.status)
        end
      end
    end
    request:send (nil)
    local result, err = coroutine.yield ()
    if result then
      return result
    else
      error (err)
    end
  end
  _G.require = function (mod_name)
    local loaded = package.loaded [mod_name]
    if loaded then
      return loaded
    end
    local preloaded = package.preload [mod_name]
    if preloaded then
      local result = preloaded (mod_name)
      package.loaded [mod_name] = result
      return result
    end
    local url = "/lua/" .. mod_name
    local result, err
    result, err = _G.loadhttp (url)
    if not result then
      error (err)
    end
    result, err = load (result, url)
    if not result then
      error (err)
    end
    result = result (mod_name)
    package.loaded [mod_name] = result
    return result
  end
  loader.hotswap = {
    require = function (_, name)
      return require (name)
    end,
    try_require = function (_, name)
      local ok, result = pcall (require, name)
      if ok then
        return result
      else
        return nil, result
      end
    end,
  }
else
  loader.scheduler = require "copas.ev"
  loader.scheduler.make_default ()
  loader.hotswap   = require "hotswap.ev" .new {
    loop = loader.scheduler._loop
  }
  loader.hotswap:require "cosy.string"
end

package.preload.bit32 = function ()
  loader.logger.warning {
    _       = "fixme",
    message = "global bit32 is created for lua-websockets",
  }
  _G.bit32         = require "bit"
  _G.bit32.lrotate = _G.bit32.rol
  _G.bit32.rrotate = _G.bit32.ror
  return _G.bit32
end

return loader