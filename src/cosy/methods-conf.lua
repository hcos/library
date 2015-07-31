local Default = require "cosy.configuration-layers".default

Default.expiration = {
  validation     =  1 * 3600, -- 1 hour
  authentication =  1 * 3600 ,-- 1 hour
  administration =  99 * 365 * 24 * 3600, -- 99 years
}

Default.reputation = {
  initial = 10,
  suspend = 50,
  release = 50,
}

Default.resource = {
  email = {
    ["/"] = {},
  },
  token = {
    ["/"] = {},
  },
  tag   = {
    ["/"] = {},
  },
  data  = {
    ["/"] = {
      ["/"] = {

      },
    },
  },
}
