return function (loader)

  local Layer  = loader.require "layeredata"

  local layers = {
    default = Layer.new { name = "default" },
    etc     = Layer.new { name = "etc"     },
    home    = Layer.new { name = "home"    },
    pwd     = Layer.new { name = "pwd"     },
    app     = Layer.new { name = "app"     },
    whole   = Layer.new { name = "whole"   },
  }

  layers.whole.__refines__ = {
    layers.default,
    layers.etc,
    layers.home,
    layers.pwd,
    layers.app,
  }

  return layers

end
