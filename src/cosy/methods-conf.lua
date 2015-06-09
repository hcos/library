local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.redis.retry = 5
Internal.redis.key   = {
  users  = "user:{{{key}}}",
  emails = "email:{{{key}}}",
  tokens = "token:{{{key}}}",
}
Internal.expiration = {
  validation     =  1 * 3600, -- 1 hour
  authentication =  1 * 3600, -- 1 hour
  administration =  99 * 365 * 24 * 3600, -- 99 years
}
Internal.reputation = {
  at_creation = 10,
  suspend     = 50,
  release     = 50,
}
