local Configuration = require "cosy.configuration"
local Lfs           = require "lfs"
local Internal      = Configuration / "default"

Internal.server = {
  interface = "127.0.0.1",
  port      = 0,
  data      = os.getenv "HOME" .. "/.cosy/server.data",
  log       = os.getenv "HOME" .. "/.cosy/server.log",
  pid       = os.getenv "HOME" .. "/.cosy/server.pid",
}
Internal.redis.retry = 5

-- Set www path:
local main = package.searchpath ("cosy.server", package.path)
if main:sub (1, 1) == "." then
  main = Lfs.currentdir () .. "/" .. main
end
Internal.http.www = main:gsub ("cosy/server.lua", "cosy/www/")
