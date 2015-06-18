local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.daemon.interface = "127.0.0.1"
Internal.daemon.port      = 0
Internal.daemon.data      = os.getenv "HOME" .. "/.cosy/daemon.data"
Internal.daemon.log       = os.getenv "HOME" .. "/.cosy/daemon.log"
Internal.daemon.pid       = os.getenv "HOME" .. "/.cosy/daemon.pid"
