package = "CosyVerif"
version = "master-1"

source = {
  url = "git://github.com/cosyverif/library",
}

description = {
  summary     = "CosyVerif Library",
  detailed    = [[]],
  homepage    = "http://www.cosyverif.org/",
  license     = "MIT/X11",
  maintainer  = "Alban Linard <alban.linard@lsv.ens-cachan.fr>",
}

dependencies = {
  "bcrypt ~> 1",
  "c3 ~> 0",
  "copas-ev ~> 1",
  "coronest ~> 0",
  "i18n ~> 0",
  "lua >= 5.1",
  "lua-websockets ~> 2",
  "luacrypto ~> 0",
  "luajwt ~> 1",
  "lualogging ~> 1",
  "luasec ~> 0",
  "luasocket ~> 3",
  "redis-lua ~> 2",
  "serpent ~> 0",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.configuration"        ] = "src/cosy/configuration.lua",
    ["cosy.configuration.default"] = "src/cosy/configuration/default.lua",
    ["cosy.data"                 ] = "src/cosy/data.lua",
    ["cosy.email"                ] = "src/cosy/email.lua",
    ["cosy.i18n.en"              ] = "src/cosy/i18n/en.lua",
    ["cosy.methods"              ] = "src/cosy/methods.lua",
    ["cosy.platform"             ] = "src/cosy/platform.lua",
    ["cosy.platform.standalone"  ] = "src/cosy/platform/standalone.lua",
    ["cosy.string"               ] = "src/cosy/string.lua",
  },
}
