return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.http = {
    nginx         = loader.prefix .. "/nginx",
    hostname      = nil,
    interface     = "*",
    port          = 8080,
    timeout       = 5,
    pid           = loader.home .. "/nginx.pid",
    configuration = loader.home .. "/nginx.conf",
    directory     = loader.home .. "/nginx",
    bundle        = loader.lua_modules .. "/cosy-full.lua",
  }

end
