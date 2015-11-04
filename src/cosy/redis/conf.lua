return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.redis = {
    interface = "localhost",
    port      = 6379,
    database  = 0,
    pool_size = 5,
  }

end
