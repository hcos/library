local Loader = require "cosy.loader"

Loader.loadhttp = function (url)
  local request = (require "copas.http").request
  local body, status = request (url)
  return body, status
end

Loader.scheduler = require "copas.ev"
Loader.scheduler.make_default ()
Loader.hotswap   = require "hotswap".new {}
Loader.nolog     = true

Loader.configure ()

return Loader
