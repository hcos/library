local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

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

Internal.permission.level.hidden  = "hidden"
Internal.permission.level.private = "private"
Internal.permission.level.user    = "user"
Internal.permission.level.public  = "public"


Internal.resource.email.key = "email:{{{key}}}"
Internal.resource.token.key = "token:{{{key}}}"

Internal.resource.user.type     = "user"
Internal.resource.user.key      = "user:{{{key}}}"
Internal.resource.user.template = {
  access       = Internal.permission.level.hidden [nil],
  avatar       = { access = Internal.permission.level.public  [nil] },
  checked      = { access = Internal.permission.level.private [nil] },
  email        = { access = Internal.permission.level.private [nil] },
  homepage     = { access = Internal.permission.level.public  [nil] },
  lastseen     = { access = Internal.permission.level.private [nil] },
  locale       = { access = Internal.permission.level.private [nil] },
  name         = { access = Internal.permission.level.public  [nil] },
  organization = { access = Internal.permission.level.public  [nil] },
  password     = { access = Internal.permission.level.hidden  [nil] },
  position     = { access = Internal.permission.level.private [nil] },
  reputation   = { access = Internal.permission.level.public  [nil] },
  status       = { access = Internal.permission.level.hidden  [nil] },
  tos_digest   = { access = Internal.permission.level.private [nil] },
  type         = { access = Internal.permission.level.hidden  [nil] },
  username     = { access = Internal.permission.level.public  [nil] },
}

Internal.resource.project.type = "project"
Internal.resource.project.key  = "project:{{{key}}}"
