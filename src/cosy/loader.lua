local version = tonumber (_VERSION:match "Lua%s*(%d%.%d)")
if version < 5.1
or (version == 5.1 and type (_G.jit) ~= "table") then
  error "Cosy requires Luajit >= 2 or Lua >= 5.2 to run."
end

local Loader = {}
local loader = {}

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
  loader.hotswap   = require
else
  local ev         = require "ev"
  loader.scheduler = require "copas.ev"
  loader.scheduler:make_default ()
  loader.hotswap   = require "hotswap" .new ()
  loader.hotswap.register = function (filename, f)
    ev.Stat.new (function ()
      f ()
    end, filename):start (loader.scheduler._loop)
  end
end

-- FIXME: remove as soon as lua-webosockets has done a new release:
package.preload ["bit32"] = function ()
  local result = require "bit"
  _G.bit32 = result
  result.lrotate = result.rol
  result.rrotate = result.ror
  return result
end

do
  Loader.__index = function (_, key)
    return loader.hotswap ("cosy." .. tostring (key))
  end
end

return setmetatable (loader, Loader)