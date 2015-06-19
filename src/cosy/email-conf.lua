local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.smtp.timeout  = 2 -- seconds
Internal.smtp.username = nil
Internal.smtp.password = nil
Internal.smtp.host     = nil
Internal.smtp.port     = nil
Internal.smtp.method   = nil
Internal.smtp.protocol = nil

Internal.redis.key.sending = "sending"
