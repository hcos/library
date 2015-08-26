local Default = require "cosy.configuration-layers".default

Default.token = {
  algorithm = "HS512",
  secret    = nil,
}

Default.expiration = {
  iteration      = 1 * 3600, -- 1 hour
  validation     = 1 * 3600, -- 1 hour
  authentication = 1 * 3600, -- 1 hour
  administration = 99 * 365 * 24 * 3600, -- 99 years
}
