local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.daemon = {
  interface = "127.0.0.1",
  port      = 0,
  data_file = os.getenv "HOME" .. "/.cosy/daemon.data",
  log_file  = os.getenv "HOME" .. "/.cosy/daemon.log",
  pid_file  = os.getenv "HOME" .. "/.cosy/daemon.pid",
}
