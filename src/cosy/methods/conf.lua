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
    email = ref.resource.email,
    token = ref.resource.token,
    tag   = ref.resource.tag,
    data  = ref.resource.data,
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
      formalism = ref.resource.formalism,
      model     = ref.resource.model,
      service   = ref.resource.service,
      execution = ref.resource.execution,
      scenario  = ref.resource.scenario,
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
