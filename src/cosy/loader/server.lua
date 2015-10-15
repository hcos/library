if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

package.preload ["cosy.loader"] = function ()
  return Loader
end

Loader.loadhttp = function (url)
  local request = (require "copas.http").request
  local body, status = request (url)
  return body, status
end

Loader.scheduler = require "copas.ev"
Loader.scheduler.make_default ()

Loader.hotswap = require "hotswap.ev" .new {
  loop = Loader.scheduler._loop,
}

_G.require = function (name)
  return Loader.hotswap.require (name)
end

if _G.logfile then
  Loader.logfile = _G.logfile
end

                 require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
