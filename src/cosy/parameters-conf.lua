local Configuration = require "cosy.configuration"
local Internal      = Configuration / "default"

Internal.data = {
  username = {
    min_size = 1,
    max_size = 32,
  },
  password = {
    min_size = 1,
    max_size = 128,
  },
  name = {
    min_size = 1,
    max_size = 128,
  },
  organization = {
    min_size = 1,
    max_size = 128,
  },
  email = {
    max_size = 128,
  },
  position = {
  },
}
