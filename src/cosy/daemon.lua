                      require "cosy.loader"
local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Handler       = require "cosy.daemon-handler"
local Logger        = require "cosy.logger"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"
local Ffi           = require "ffi"
local Websocket     = require "websocket"

Configuration.load {
  "cosy.daemon",
  "cosy.server",
}

local i18n   = I18n.load "cosy.daemon"
i18n._locale = Configuration.locale

local Daemon = {}

Daemon.libraries = {}

function Daemon.start ()
  local addserver = Scheduler.addserver
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      Configuration.daemon.port = port
    end
    addserver (s, f)
  end
  Daemon.ws = Websocket.server.copas.listen {
    interface = Configuration.daemon.interface,
    port      = Configuration.daemon.port,
    protocols = {
      cosy = function (ws)
        while true do
          local message = ws:receive ()
          Logger.debug {
            _       = i18n ["daemon:request"],
            message = message,
          }
          if not message then
            ws:close ()
            return
          end
          local response
          if message == "daemon-stop" then
            Daemon.stop ()
            response = Value.expression {
              success = true,
            }
          else
            response = Handler (message)
          end
          Logger.debug {
            _       = i18n ["daemon:response"],
            message = message,
          }
          ws:send (response)
        end
      end
    }
  }
  Scheduler.addserver = addserver
  Logger.debug {
    _    = i18n ["websocket:listen"],
    host = Configuration.daemon.interface,
    port = Configuration.daemon.port,
  }
  do
    local daemonfile = Configuration.daemon.data
    local file       = io.open (daemonfile, "w")
    file:write (Value.expression {
      interface = Configuration.daemon.interface,
      port      = Configuration.daemon.port,
    })
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = daemonfile })
  end
  do
    Ffi.cdef [[ unsigned int getpid (); ]]
    local pidfile = Configuration.daemon.pid
    local file    = io.open (pidfile, "w")
    file:write (Ffi.C.getpid ())
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = pidfile })
  end
  Scheduler.loop ()
end

function Daemon.stop ()
  os.remove (Configuration.daemon.data)
  Scheduler.addthread (function ()
    Scheduler.sleep (1)
    os.remove (Configuration.daemon.pid )
    os.exit   (0)
  end)
end

return Daemon
