return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  if not Default.webclient then
    Default.webclient = {}
  end

  Default.webclient.authentication = {
    password_size = 8,
  }

end
