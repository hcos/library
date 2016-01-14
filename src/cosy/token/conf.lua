return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.token = {
    algorithm = "HS256",
    secret    = nil,
  }

  Default.expiration = {
    identification = 99 * 365 * 24 * 3600, -- 99 years
    validation     = 1 * 3600, -- 1 hour
    authentication = 1 * 3600, -- 1 hour
    administration = 99 * 365 * 24 * 3600, -- 99 years
  }

end
