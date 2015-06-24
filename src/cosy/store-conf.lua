local Default = require "cosy.configuration-layers".default

Default.store = {
  pattern = {
    user     = "{{{user}}}",
    project  = "{{{user}}}/{{{project}}}",
    resource = "{{{user}}}/{{{project}}}/{{{resource}}}",
  },
}
