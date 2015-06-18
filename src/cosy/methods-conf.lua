local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.redis.key.emails   = "email:{{{key}}}"
Internal.redis.key.projects = "project:{{{key}}}"
Internal.redis.key.tokens   = "token:{{{key}}}"
Internal.redis.key.users    = "user:{{{key}}}"

Internal.redis.pattern.user     = "{{{user}}}"
Internal.redis.pattern.project  = "{{{user}}}/{{{project}}}"
Internal.redis.pattern.resource = "{{{user}}}/{{{project}}}/{{{resource}}}"

Internal.expiration.validation     =  1 * 3600 -- 1 hour
Internal.expiration.authentication =  1 * 3600 -- 1 hour
Internal.expiration.administration =  99 * 365 * 24 * 3600 -- 99 years

Internal.reputation.at_creation = 10
Internal.reputation.suspend     = 50
Internal.reputation.release     = 50

Internal.resource.status.active    = "active"
Internal.resource.status.suspended = "suspended"

Internal.resouce.type.user    = "user"
Internal.resouce.type.project = "project"
