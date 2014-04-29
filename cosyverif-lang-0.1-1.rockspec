package = "CosyVerif-Lang"
version = "0.1-1"

source = {
   url = "...",
}

description = {
  summary     = "CosyVerif Language for Formalisms & Models",
  detailed    = [[
  ]],
  homepage    = "http://www.cosyverif.org/",
  license     = "MIT/X11",
  maintainer  = "Alban Linard <alban.linard@lsv.ens-cachan.fr>",
}

dependencies = {
  "lua >= 5.1",
  "luassert >= 1.7",
  "telescope >= 0.6",
}

build = {
  type    = "builtin",
  modules = {
  },
}
