local Default = require "cosy.configuration.layers".default
local ref     = require "layeredata".reference (false)

Default.filter = {
  timeout = 2, -- seconds
}

Default.reputation = {
  initial = 10,
  suspend = 50,
  release = 50,
}

Default.resource = {
  ["/"] = {
    ref.resource.email,
    ref.resource.token,
    ref.resource.tag,
    ref.resource.data,
  },
  email = {
    ["/"] = {},
  },
  token = {
    ["/"] = {},
  },
  tag = {
    ["/"] = {},
  },
  data = {
    ["/"] = {
      ref.resource.user,
    },
  },
  user = {
    ["/"] = {
      ref.resource.project,
    },
  },
  project = {
    ["/"] = {
      ref.resource.formalism,
      ref.resource.model,
      ref.resource.service,
      ref.resource.execution,
      ref.resource.scenario,
    },
  },
  formalism = {
    ["/"] = {},
  },
  model = {
    ["/"] = {},
  },
  service  = {
    ["/"] = {},
  },
  execution = {
    ["/"] = {},
  },
  scenario = {
    ["/"] = {},
  },
}
