package.path  = package.path:gsub ("'", "")
  .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;"

local Loader        = require "cosy.loader"
local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Nginx         = require "cosy.nginx"
local Random        = require "cosy.random"
local Redis         = require "cosy.redis"
local Scheduler     = require "cosy.scheduler"
local Handler       = require "cosy.server-handler"
local Token         = require "cosy.token"
local Value         = require "cosy.value"
local App           = require "cosy.configuration-layers".app
local Layer         = require "layeredata"
local Websocket     = require "websocket"
local Ffi           = require "ffi"


local i18n   = I18n.load "cosy.server"
i18n._locale = Configuration.locale

local Server = {}

local updater = Scheduler.addthread (function ()
  while true do
    local redis = Redis ()
    -- http://stackoverflow.com/questions/4006324
    local script = { [[
      local n    = 1000
      local keys = redis.call ("keys", ARGV[1])
      for i=1, #keys, n do
        redis.call ("del", unpack (keys, i, math.min (i+n-1, #keys)))
      end
    ]] }
    for name, p in Layer.pairs (Configuration.dependencies) do
      local url = p
      if type (url) == "string" and url:match "^http" then
        script [#script+1] = ([[
          redis.call ("set", "foreign:{{{name}}}", "{{{source}}}")
        ]]) % {
          name   = name,
          source = url,
        }
      end
    end
    script [#script+1] = [[
      return true
    ]]
    script = table.concat (script)
    redis:eval (script, 1, "foreign:*")
    os.execute ([[
      if [ -d {{{root}}}/cache ]
      then
        find {{{root}}}/cache -type f -delete
      fi
    ]] % {
      root = Configuration.http.directory,
    })
    Logger.debug {
      _ = i18n ["updated"],
    }
    Nginx.update ()
    Scheduler.sleep (-math.huge)
  end
end)

function Server.start ()
  App.server          = {}
  Server.passphrase   = Digest (Random ())
  Server.token        = Token.administration (Server)
  local addserver     = Scheduler.addserver
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      App.server.port = port
    end
    addserver (s, f)
  end
  Server.ws = Websocket.server.copas.listen {
    interface = Configuration.server.interface,
    port      = Configuration.server.port     ,
    protocols = {
      cosy = function (ws)
        while true do
          local message = ws:receive ()
          Logger.debug {
            _       = i18n ["server:request"],
            message = message,
          }
          if not message then
            ws:close ()
            return
          end
          local response = Handler (message)
          Logger.debug {
            _       = i18n ["server:response"],
            message = response,
          }
          ws:send (response)
        end
      end
    }
  }
  Scheduler.addserver = addserver
  Logger.debug {
    _    = i18n ["websocket:listen"],
    host = Configuration.server.interface,
    port = Configuration.server.port     ,
  }
  do
    Nginx.stop  ()
    Nginx.start ()
  end
  do
    local datafile = Configuration.server.data
    local file     = io.open (datafile, "w")
    file:write (Value.expression {
      token     = Server.token,
      interface = Configuration.server.interface,
      port      = Configuration.server.port     ,
    })
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = datafile })
  end
  do
    Ffi.cdef [[ unsigned int getpid (); ]]
    local pidfile = Configuration.server.pid
    local file    = io.open (pidfile, "w")
    file:write (Ffi.C.getpid ())
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = pidfile })
  end
  
  
  Loader.hotswap.on_change ["cosy:configuration"] = function ()
    Scheduler.wakeup (updater)
  end

  Scheduler.loop ()
end

function Server.stop ()
  os.remove (Configuration.server.data)
  Scheduler.addthread (function ()
    Scheduler.sleep (1)
    Nginx.stop ()
    os.remove (Configuration.server.pid )
    os.exit   (0)
  end)
end

return Server
