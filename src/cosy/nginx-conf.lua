local Lfs     = require "lfs"
local Default = require "cosy.configuration-layers".default

-- Compute www path:
local main = package.searchpath ("cosy.nginx", package.path)
if main:sub (1, 1) == "." then
  main = Lfs.currentdir () .. "/" .. main
end

Default.http = {
  nginx         = "nginx",
  interface     = "*",
  port          = 80,
  timeout       = 5,
  pid           = os.getenv "HOME" .. "/.cosy/nginx.pid",
  configuration = os.getenv "HOME" .. "/.cosy/nginx.conf",
  error         = os.getenv "HOME" .. "/.cosy/nginx.log",
  directory     = os.getenv "HOME" .. "/.cosy/nginx/",
  uploads       = os.getenv "HOME" .. "/.cosy/nginx/uploads",
  www           = main:gsub ("cosy/nginx.lua", "cosy/www/"),
}

Default.dependencies = {
  expiration = 24 * 3600, -- 1 day
  ["/js/lua.vm.js"] = "https://kripken.github.io/lua.vm.js/lua.vm.js",
  ["/js/sjcl.js"  ] = "http://bitwiseshiftleft.github.io/sjcl/sjcl.js",
  ["/js/jquery.js"] = "http://code.jquery.com/jquery-2.1.4.min.js",
}
