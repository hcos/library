local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.cli = {
  directory      = os.getenv "HOME" .. "/.cosy",
  default_locale = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
  default_server = "http://cosyverif.org/",
}
