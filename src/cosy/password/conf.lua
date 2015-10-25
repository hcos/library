return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.password = {
    time = 0.020, -- 20 milliseconds
  }

end
