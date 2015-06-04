local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.redis = {
  interface = "127.0.0.1",
  port      = 6379,
  database  = 0,
  pool_size = 5,
}
