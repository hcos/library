local Default = require "cosy.configuration.layers".default

Default.cli = {
  directory = os.getenv "HOME" .. "/.cosy",
  locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
  server    = "http://cosyverif.org/",
}
