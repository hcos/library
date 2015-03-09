local Configuration = require "cosy.configuration" .whole
local Platform      = require "cosy.platform"
                      require "cosy.string"
local copas         = require "copas"
local websocket     = require "websocket"

local nb_threads    = 10
local nb_iterations = 10

local running  = 0
local closed   = 0
local sent     = {}
local received = {}

do
  local redis     = require "redis"
  local host      = Configuration.redis.host._
  local port      = Configuration.redis.port._
  local database  = Configuration.redis.database._
  local client    = redis.connect (host, port)
  client:select (database)
  client:flushall ()
end

for thread = 1, nb_threads  do
  sent     [thread] = 0
  received [thread] = 0
  copas.addthread (function ()
    local client = websocket.client.copas {
      timeout = 5
    }
    local url = "ws://%{host}:%{port}" % {
      host = Configuration.server.host._,
      port = tonumber (Configuration.server.port._),
    }
    client:connect (url, "cosy")
    running = running + 1
    
    local information
    do
      client:send (Platform.table.encode {
        version = "2.0",
        method  = "information",
        params  = {
          token   = nil,
          request = nil,
        },
        id = "inforamtion",
      })
      local message = client:receive ()
      local _, result = Platform.table.decode (message)
      information = result.result
    end
    local tos
    do
      client:send (Platform.table.encode {
        version = "2.0",
        method  = "tos",
        params  = {
          token   = nil,
          request = nil,
        },
        id = "tos",
      })
      local message = client:receive ()
      local _, result = Platform.table.decode (message)
      tos = result.result
    end
    local validation
    do
      client:send (Platform.table.encode {
        version = "2.0",
        method  = "create-user",
        params  = {
          token   = nil,
          request = {
            username   = "user-" .. tostring (thread),
            password   = "password",
            email      = "user-" .. tostring (thread) .. "@machin.fr",
            tos_digest = tos.tos_digest,
            locale     = "en",
            name       = "User " .. tostring (thread),
          },
        },
        id = "create-user",
      })
      local message = client:receive ()
      local _, result = Platform.table.decode (message)
      validation = result.result.token
    end
    do
      client:send (Platform.table.encode {
        version = "2.0",
        method  = "activate-user",
        params  = {
          token   = validation,
          request = nil,
        },
        id = "activate-user",
      })
      local message = client:receive ()
      local _, result = Platform.table.decode (message)
    end
    local token
    do
      client:send (Platform.table.encode {
        version = "2.0",
        method  = "authenticate",
        params  = {
          token   = nil,
          request = {
            username = "user-" .. tostring (thread),
            password = "password",
          },
        },
        id = "authenticate",
      })
      local message = client:receive ()
      local _, result = Platform.table.decode (message)
      token = result.result.token
    end
    for id = 1, nb_iterations do
      copas.addthread (function ()
         local client = websocket.client.copas {
          timeout = 5
        }
        local url = "ws://%{host}:%{port}" % {
          host = Configuration.server.host._,
          port = tonumber (Configuration.server.port._),
        }
        client:connect (url, "cosy")
        client:send (Platform.table.encode {
              version = "2.0",
          method  = "information",
          params  = {
            token   = token,
            request = nil,
          },
          id = tostring (id),
        })
        sent     [thread] = sent     [thread] + 1
        local message = client:receive ()
        received [thread] = received [thread] + 1
      end)
    end
    copas.addthread (function ()
      while true do
        if sent [thread] == nb_iterations then
          copas.sleep (1)
          client:close ()
          closed = closed + 1
          print ("closed", closed)
          break
        end
        copas.sleep (0.01)
      end
    end)
  end)
end

copas.addthread (function ()
  while true do
    local r = 0
    for _, v in pairs (received) do
      r = r + v
    end
    if closed == nb_threads then
      print ("received", r * 100 / (nb_threads * nb_iterations), "%")
      os.exit (0)
    else
      print ("received", r * 100 / (nb_threads * nb_iterations), "%")
      copas.sleep (0.1)
    end
  end
end)

copas.loop ()