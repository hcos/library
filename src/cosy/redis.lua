local loader  = require "cosy.loader"
local hotswap = loader.hotswap

if _G.js then
  error "Not available"
end

local assigned = {}

return function ()
  local redis         = hotswap "redis"
  local configuration = loader.configuration
  local scheduler     = loader.scheduler
  local socket        = loader.socket
  local co            = coroutine.running ()
  local found         = assigned [co]
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
    if count < configuration.redis.pool_size._ then
      local coroutine = hotswap "coroutine.make" ()
      local host      = configuration.redis.host._
      local port      = configuration.redis.port._
      local database  = configuration.redis.database._
      local socket    = socket ()
      socket:connect (host, port)
      local client = redis.connect {
        socket    = socket,
        coroutine = coroutine,
      }
      client:select (database)
      assigned [co] = client
      return client
    else
      scheduler.sleep (0.01)
    end
  until false
end
