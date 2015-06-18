local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.http.nginx         = "nginx"
Internal.http.interface     = "*"
Internal.http.port          = 80
Internal.http.timeout       = 5
Internal.http.pid           = os.getenv "HOME" .. "/.cosy/nginx.pid"
Internal.http.configuration = os.getenv "HOME" .. "/.cosy/nginx.conf"
Internal.http.error         = os.getenv "HOME" .. "/.cosy/nginx.log"
Internal.http.directory     = os.getenv "HOME" .. "/.cosy/nginx/"
Internal.http.uploads       = os.getenv "HOME" .. "/.cosy/nginx/uploads"

Internal.www.root = (os.getenv "PWD") .. "/www"

Internal.dependencies.expiration = 24 * 3600 -- 1 day
Internal.dependencies ["/js/lua.vm.js"] = "https://kripken.github.io/lua.vm.js/lua.vm.js"
Internal.dependencies ["/js/sjcl.js"  ] = "http://bitwiseshiftleft.github.io/sjcl/sjcl.js"
Internal.dependencies ["/js/jquery.js"] = "http://code.jquery.com/jquery-2.1.4.min.js"
