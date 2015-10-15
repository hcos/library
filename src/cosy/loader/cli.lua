if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

package.preload ["cosy.loader"] = function ()
  return Loader
end

Loader.loadhttp = function (url)
  local request = (require "socket.http").request
  local body, status = request (url)
  return body, status
end

Loader.scheduler = require "copas"
Loader.hotswap   = require "hotswap" .new {}
Loader.nolog     = true

table.insert (package.searchers, 2, function (name)
  if not Loader.server then
    return nil
  end
  local url = Loader.server .. "/lua/" .. name
  local result, err
  result, err = Loader.loadhttp (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)

local Coromake = require "coroutine.make"
_G.coroutine   = Coromake ()

return Loader
