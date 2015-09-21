local Default = require "cosy.configuration.layers".default

Default.filter = {
  timeout = 2, -- seconds
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
