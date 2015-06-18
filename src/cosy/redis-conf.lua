local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.redis.interface = "127.0.0.1"
Internal.redis.port      = 6379
Internal.redis.database  = 0
Internal.redis.pool_size = 5
