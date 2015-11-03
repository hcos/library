return function (loader)

  local Default = loader.load "cosy.configuration.layers".default
  local Key     = loader.load "cosy.store.key"

  Default.smtp = {
    timeout   = 2, -- seconds
    username  = nil,
    password  = nil,
    host      = nil,
    port      = nil,
    method    = nil,
    protocol  = nil,
    redis_key = Key.encode "sending",
  }

end
