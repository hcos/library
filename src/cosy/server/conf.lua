local Default = require "cosy.configuration.layers".default

Default.server = {
  interface = "127.0.0.1",
  port      = 0, -- random port
  data      = os.getenv "HOME" .. "/.cosy/server.data",
  log       = os.getenv "HOME" .. "/.cosy/server.log",
  pid       = os.getenv "HOME" .. "/.cosy/server.pid",
  geodata   = os.getenv "HOME" .. "/.cosy/geodata.dat",
  retry     = 5,
  name      = nil,
}

Default.recaptcha = {
  public_key  = nil,
  private_key = nil,
}
