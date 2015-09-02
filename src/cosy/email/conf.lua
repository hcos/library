local Default = require "cosy.configuration.layers".default

Default.smtp = {
  timeout   = 2, -- seconds
  username  = nil,
  password  = nil,
  host      = nil,
  port      = nil,
  method    = nil,
  protocol  = nil,
  redis_key = require "cosy.store.key".encode "sending",
}
