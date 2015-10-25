local loader        = require "cosy.loader.lua" {
  logto = os.getenv "HOME" .. "/.cosy/daemon.log",
}
local Configuration = loader.load "cosy.configuration"
local I18n          = loader.load "cosy.i18n"
local Library       = loader.load "cosy.library"
local Logger        = loader.load "cosy.logger"
local Value         = loader.load "cosy.value"
local Scheduler     = loader.load "cosy.scheduler"
local App           = loader.load "cosy.configuration.layers".app
local Ffi           = loader.require "ffi"
local Websocket     = loader.require "websocket"

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
        local message
        local function send (t)
          local response = Value.expression (t)
          Logger.debug {
            _        = i18n ["daemon:response"],
            request  = message,
            response = response,
          }
          ws:send (response)
        end
        while ws.state == "OPEN" do
          message = ws:receive ()
          Logger.debug {
            _       = i18n ["daemon:request"],
            request = message,
          }
          if message == "daemon-stop" then
            Daemon.stop ()
            return send {
              success = true,
            }
          elseif message then
            Scheduler.addthread (function ()
              local decoded, request = pcall (Value.decode, message)
              if not decoded or type (request) ~= "table" then
                return send (i18n {
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
                  return send (i18n {
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
              if result == nil then
                return send {
                  success = false,
                  error   = err,
                }
              elseif type (result) == "function" then
                send {
                  success  = true,
                  iterator = true,
                }
                local ok, ierr = pcall (function ()
                  for subresult in result do
                    send {
                      success  = true,
                      response = subresult,
                    }
                  end
                end)
                return send {
                  success  = ok,
                  finished = true,
                  error    = ierr,
                }
              else
                return send {
                  success  = true,
                  response = result,
                }
              end
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
    os.remove (Configuration.daemon.pid)
    os.exit   (0)
  end)
end

return Daemon
