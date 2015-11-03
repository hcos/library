if _G.js then
  error "Not available"
end

return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Scheduler     = loader.load "cosy.scheduler"
  local Socket        = loader.load "cosy.socket"
  local Redis         = loader.require "redis"

  Configuration.load "cosy.redis"

  local assigned = {}

  return function ()
    local co    = coroutine.running ()
    local found = assigned [co]
    if found then
      return found
    end
    repeat
      local count = 0
      for other, client in pairs (assigned) do
        if coroutine.status (other) == "dead" then
          assigned [other] = nil
          if pcall (client.ping, client) then
            assigned [co] = client
            return client
          end
        else
          count = count+1
        end
      end
      if count < Configuration.redis.pool_size then
        local coroutine = require "coroutine.make" ()
        local host      = Configuration.redis.interface
        local port      = Configuration.redis.port
        local database  = Configuration.redis.database
        local socket    = Socket ()
        socket:connect (host, port)
        local client = Redis.connect {
          socket    = socket,
          coroutine = coroutine,
        }
        client:select (database)
        assigned [co] = client
        return client
      else
        Scheduler.sleep (0.01)
      end
    until false
  end

end
