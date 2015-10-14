local Loader = require "cosy.loader"

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

Loader.configure ()

return Loader
