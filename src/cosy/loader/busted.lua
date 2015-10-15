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
Loader.hotswap   = require "hotswap".new {}
Loader.nolog     = true

                 require "cosy.string"
local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
