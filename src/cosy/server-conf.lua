local Configuration = require "cosy.configuration"
local Lfs           = require "lfs"
local Internal      = Configuration / "default"

Internal.server = {
  interface = "127.0.0.1",
  port      = 0,
  data_file = os.getenv "HOME" .. "/.cosy/server.data",
  log_file  = os.getenv "HOME" .. "/.cosy/server.log",
  pid_file  = os.getenv "HOME" .. "/.cosy/server.pid",
}

-- Set www path:
local main = package.searchpath ("cosy.server", package.path)
if main:sub (1, 1) == "." then
  main = Lfs.currentdir () .. "/" .. main
end
Internal.http.www = main:gsub ("cosy/server.lua", "cosy/www/")
