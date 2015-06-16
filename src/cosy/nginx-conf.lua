local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.http  = {
  nginx         = "nginx",
  interface     = "*",
  port          = 8080,
  salt          = "cosyverif",
  timeout       = 5,
  pid           = os.getenv "HOME" .. "/.cosy/nginx.pid",
  configuration = os.getenv "HOME" .. "/.cosy/nginx.conf",
  error         = os.getenv "HOME" .. "/.cosy/nginx.log",
  directory     = os.getenv "HOME" .. "/.cosy/nginx/",
}
Internal.www = {
  root = (os.getenv "PWD") .. "/www",
}
Internal.dependencies = {
  expiration = 24 * 3600, -- 1 day
  ["/js/lua.vm.js"] = "https://kripken.github.io/lua.vm.js/lua.vm.js",
  ["/js/sjcl.js"  ] = "http://bitwiseshiftleft.github.io/sjcl/sjcl.js",
  ["/js/jquery.js"] = "http://code.jquery.com/jquery-2.1.4.min.js",
}
