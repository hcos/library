local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.cli.directory = os.getenv "HOME" .. "/.cosy"
Internal.cli.locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-")
Internal.cli.server    = "http://cosyverif.org/"
