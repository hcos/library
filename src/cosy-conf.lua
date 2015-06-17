local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.cli = {
  directory = os.getenv "HOME" .. "/.cosy",
  locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
  server    = "http://cosyverif.org/",
}
