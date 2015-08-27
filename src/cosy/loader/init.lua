if not package.searchpath
or #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

local loader = setmetatable ({}, Loader)

if _G.logfile then
  loader.logfile = _G.logfile
end

if _G.js then
  package.loaded ["cosy.loader"] = loader
  loader.loadhttp = function (url)
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
    result, err = loader.loadhttp (url)
    if not result then
      error (err)
    end
    return load (result, url)
  end)
  loader.hotswap   = require "hotswap" .new {}
else
  loader.loadhttp  = function (url)
    local request = (require "copas.http").request
    local body, status = request (url)
    return body, status
  end
  loader.scheduler = require "copas.ev"
  loader.scheduler.make_default ()
  loader.hotswap   = require "hotswap.ev" .new {
    loop = loader.scheduler._loop,
  }
end

do
  package.preload ["bit32"] = function ()
    _G.bit32         = require "bit"
    _G.bit32.lrotate = _G.bit32.rol
    _G.bit32.rrotate = _G.bit32.ror
    return _G.bit32
  end

  _G.require = function (name)
    return loader.hotswap.require (name)
  end

  require "cosy.string"

  local Coromake = require "coroutine.make"
  _G.coroutine   = Coromake ()
end

return loader
