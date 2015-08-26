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
local Handler       = require "cosy.server.handler"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Value         = require "cosy.value"
local App           = require "cosy.configuration.layers".app
local Default       = require "cosy.configuration.layers".default
local Layer         = require "layeredata"
local Websocket     = require "websocket"
local Ffi           = require "ffi"

local i18n   = I18n.load "cosy.server"
i18n._locale = Configuration.locale

local Server = {}

Scheduler.addthread (function ()
  Store.initialize ()
end)

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
          redis.call ("set", "/foreign/{{{name}}}", "{{{source}}}")
        ]]) % {
          name   = name,
          source = url,
        }
      end
    end
    for name, p in Layer.pairs (Configuration.externals) do
      local url = p
      if type (url) == "string" and url:match "^http" then
        script [#script+1] = ([[
          redis.call ("set", "/external/{{{name}}}", "{{{source}}}")
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
    redis:eval (script, 1, "/foreign/*")
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

function Server.sethostname ()
  local hostname
  local Http = require "socket.http"
  local ip, status = Http.request "http://ip.telize.com/"
  if status == 200 then
    ip = ip:match "%S+"
    local handle = io.popen ("host " .. ip)
    hostname = handle:read "*all"
    handle:close()
    local results = {}
    for r in hostname:gmatch "%S+" do
      results [#results+1] = r
    end
    hostname = results [#results]
    hostname = hostname:sub (1, #hostname-1)
  end
  if not hostname or hostname:match "%.home$" then
    local handle = io.popen "hostname"
    hostname = handle:read "*all"
    handle:close()
  end
  Default.http.hostname = hostname
  Logger.info {
    _        = i18n ["server:hostname"],
    hostname = Default.server.hostname,
  }
end

function Server.setname ()
  local name
  local handle = io.popen "hostname"
  name = handle:read "*l"
  handle:close()
  Default.server.name = name
  Logger.info {
    _    = i18n ["server:name"],
    name = Default.server.name,
  }
end

function Server.start ()
  if not Configuration.http.hostname then
    Server.sethostname ()
  end
  if not Configuration.server.name then
    Server.setname ()
  end
  App.server            = {}
  App.server.passphrase = Digest (Random ())
  App.server.token      = Token.administration ()
  local addserver       = Scheduler.addserver
  Scheduler.addserver   = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      App.server.port = port
    end
    addserver (s, f)
  end
  Server.ws = Websocket.server.copas.listen {
    interface = Configuration.server.interface,
    port      = Configuration.server.port,
    protocols = {
      cosy = function (ws)
        while ws.state == "OPEN" do
          local message = ws:receive ()
          Logger.debug {
            _       = i18n ["server:request"],
            request = message,
          }
          if message then
            Scheduler.addthread (function ()
              local response = Handler (message, ws)
              Logger.debug {
                _        = i18n ["server:response"],
                request  = message,
                response = response,
              }
              ws:send (response)
            end)
          end
        end
      end
    }
  }
  Scheduler.addserver = addserver
  Logger.debug {
    _    = i18n ["websocket:listen"],
    host = Configuration.server.interface,
    port = Configuration.server.port,
  }

  do
    Nginx.start ()
  end

  do
    local datafile = Configuration.server.data
    local file     = io.open (datafile, "w")
    file:write (Value.expression {
      token     = Configuration.server.token,
      interface = Configuration.server.interface,
      port      = Configuration.server.port,
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
    os.execute ([[
      rm -rf {{{pid}}} {{{data}}}
    ]] % {
      pid  = Configuration.server.pid,
      data = Configuration.server.data,
    })
    os.exit (0)
  end)
end

return Server
