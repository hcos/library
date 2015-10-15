local Default = require "cosy.configuration.layers".default

Default.cli = {
  data      = os.getenv "HOME" .. "/.cosy/cli.data",
  directory = os.getenv "HOME" .. "/.cosy",
  locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
  log       = os.getenv "HOME" .. "/.cosy/cli.log",
  server    = "http://cosyverif.org/",
}
