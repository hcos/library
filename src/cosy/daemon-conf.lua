local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.daemon = {
  interface = "127.0.0.1",
  port      = 0,
  data      = os.getenv "HOME" .. "/.cosy/daemon.data",
  log       = os.getenv "HOME" .. "/.cosy/daemon.log",
  pid       = os.getenv "HOME" .. "/.cosy/daemon.pid",
}
