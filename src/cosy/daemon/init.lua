                      require "cosy.loader"
local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Library       = require "cosy.library"
local Logger        = require "cosy.logger"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"
local App           = require "cosy.configuration.layers".app
local Ffi           = require "ffi"
local Websocket     = require "websocket"

Configuration.load {
  "cosy.daemon",
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.daemon",
  "cosy.server",
}
i18n._locale = Configuration.locale

local Daemon = {}

Daemon.libraries = {}

function Daemon.start ()
  local addserver = Scheduler.addserver
  App.daemon = {}
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      App.daemon.port = port
    end
    addserver (s, f)
  end
  Daemon.ws = Websocket.server.copas.listen {
    interface = Configuration.daemon.interface,
    port      = Configuration.daemon.port,
    protocols = {
      cosy = function (ws)
        while ws.state == "OPEN" do
          local message = ws:receive ()
          Logger.debug {
            _       = i18n ["daemon:request"],
            request = message,
          }
          if message == "daemon-stop" then
            Daemon.stop ()
            ws:send (Value.expression {
              success = true,
            })
          elseif message then
            Scheduler.addthread (function ()
              local decoded, request = pcall (Value.decode, message)
              if not decoded or type (request) ~= "table" then
                return Value.expression (i18n {
                  success = false,
                  error   = i18n {
                    _ = i18n ["message:invalid"] % {},
                  },
                })
              end
              local server = request.server
              local lib    = Daemon.libraries [server]
              if not lib then
                lib = Library.connect (server)
                if not lib then
                  return Value.expression (i18n {
                    success = false,
                    error   = {
                      _ = i18n ["server:unreachable"] % {},
                    },
                  })
                end
                Daemon.libraries [server] = lib
              end
              local method = lib [request.operation]
              local result, err = method (request.parameters, request.try_only)
              if result then
                result = {
                  success  = true,
                  response = result,
                }
              else
                result = {
                  success = false,
                  error   = err,
                }
              end
              local response = Value.expression (result)
              Logger.debug {
                _        = i18n ["daemon:response"],
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
