package.path  = package.path:gsub ("'", "")
  .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;"

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Nginx         = require "cosy.nginx"
local Random        = require "cosy.random"
local Scheduler     = require "cosy.scheduler"
local Handler       = require "cosy.server-handler"
local Token         = require "cosy.token"
local Value         = require "cosy.value"
local Websocket     = require "websocket"
local Ffi           = require "ffi"

local i18n   = I18n.load "cosy.server"
i18n._locale = Configuration.locale [nil]

local Server = {}

function Server.start ()
  Server.passphrase = Digest (Random ())
  Server.token      = Token.administration (Server)
  local addserver = Scheduler.addserver
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      Configuration.server.port = port
    end
    addserver (s, f)
  end
  Server.ws = Websocket.server.copas.listen {
    interface = Configuration.server.interface [nil],
    port      = Configuration.server.port      [nil],
    protocols = {
      cosy = function (ws)
        while true do
          local message = ws:receive ()
          if not message then
            ws:close ()
            return
          end
          ws:send (Handler (message))
        end
      end
    }
  }
  Scheduler.addserver = addserver
  Logger.debug {
    _    = i18n ["websocket:listen"],
    host = Configuration.server.interface [nil],
    port = Configuration.server.port      [nil],
  }
  do
    local datafile = Configuration.server.data [nil]
    local file     = io.open (datafile, "w")
    file:write (Value.expression {
      token     = Server.token,
      interface = Configuration.server.interface [nil],
      port      = Configuration.server.port      [nil],
    })
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = datafile })
  end
  do
    Nginx.stop  ()
    Nginx.start ()
  end
  do
    Ffi.cdef [[ unsigned int getpid (); ]]
    local pidfile = Configuration.server.pid [nil]
    local file    = io.open (pidfile, "w")
    file:write (Ffi.C.getpid ())
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = pidfile })
  end
  Scheduler.loop ()
end

function Server.stop ()
  os.remove (Configuration.server.data [nil])
  os.remove (Configuration.server.pid  [nil])
  Scheduler.addthread (function ()
    Scheduler.sleep (1)
    Nginx.stop ()
    os.exit   (0)
  end)
end

return Server
