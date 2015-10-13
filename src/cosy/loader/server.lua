local Loader = require "cosy.loader"

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

Loader.configure ()

return Loader
