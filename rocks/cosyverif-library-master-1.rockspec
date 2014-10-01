package = "CosyVerif-Library"
version = "master-1"

source = {
   url = "git://github.com/cosyverif/library",
}

description = {
  summary     = "CosyVerif Library",
  detailed    = [[
  ]],
  homepage    = "http://www.cosyverif.org/",
  license     = "MIT/X11",
  maintainer  = "Alban Linard <alban.linard@lsv.ens-cachan.fr>",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type    = "builtin",
  modules = {
    ["cosy"                 ] = "src/cosy.lua",
    ["cosy.patches"         ] = "src/cosy/patches.lua",
    ["cosy.data"            ] = "src/cosy/data.lua",
    ["cosy.util.string"     ] = "src/cosy/util/string.lua",
    ["cosy.util.ignore"     ] = "src/cosy/util/ignore.lua",
    ["cosy.protocol"        ] = "src/cosy/protocol.lua",
    ["cosy.tag"             ] = "src/cosy/tag.lua",
    ["cosy.algorithm"       ] = "src/cosy/algorithm.lua",
    ["cosy.dump"            ] = "src/cosy/dump.lua",
    ["cosy.platform.js"     ] = "src/cosy/platform/js.lua",
    ["cosy.platform.ev"     ] = "src/cosy/platform/ev.lua",
    ["cosy.platform.dummy"  ] = "src/cosy/platform/dummy.lua",
  },
}
