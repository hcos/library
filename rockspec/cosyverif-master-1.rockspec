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
  "lua >= 5.1",
  "lualogging ~> 1",
  "lua-log ~> 0",
  "luasocket ~> 3",
  "luasec ~> 0",
  "yaml ~> 1",
  "lua-cjson ~> 2",
  "serpent ~> 0",
  "lua-csnappy ~> 0",
  "bcrypt ~> 1",
  "luafilesystem ~> 1",
  "redis-lua ~> 2",
  -- for testing:
  "fakeredis ~> 0",
  "luabitop ~> 1",
  "busted ~> 2",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy.platform"            ] = "src/cosy/platform.lua",
    ["cosy.platform.standalone" ] = "src/cosy/platform/standalone.lua",
    ["cosy.configuration"       ] = "src/cosy/configuration.lua",
    ["cosy.backend.redis"       ] = "src/cosy/backend/redis.lua",
  },
}
