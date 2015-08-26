local Default = require "cosy.configuration.layers".default

Default.daemon = {
  interface = "127.0.0.1",
  port      = 0,
  data      = os.getenv "HOME" .. "/.cosy/daemon.data",
  log       = os.getenv "HOME" .. "/.cosy/daemon.log",
  pid       = os.getenv "HOME" .. "/.cosy/daemon.pid",
}
