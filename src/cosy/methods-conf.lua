local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.redis.key   = {
  emails   = "email:{{{key}}}",
  projects = "project:{{{key}}}",
  tokens   = "token:{{{key}}}",
  users    = "user:{{{key}}}",
}
Internal.redis.pattern = {
  user     = "{{{user}}}",
  project  = "{{{user}}}/{{{project}}}",
  resource = "{{{user}}}/{{{project}}}/{{{resource}}}",
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
Internal.resource.status = {
  active    = "active",
  suspended = "suspended",
}
Internal.resouce.type = {
  user    = "user",
  project = "project",
}
