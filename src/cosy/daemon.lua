local Configuration = require "cosy.configuration"

Configuration.load "cosy.server"
local Internal  = Configuration / "default"
Internal.daemon = {
  interface = "127.0.0.1",
  port      = 0,
  data_file = os.getenv "HOME" .. "/.cosy/daemon.data",
  log_file  = os.getenv "HOME" .. "/.cosy/daemon.log",
  pid_file  = os.getenv "HOME" .. "/.cosy/daemon.pid",
}
if _G ["cosy:configuration-only"] then
  return
end

local I18n          = require "cosy.i18n"
local Library       = require "cosy.library"
local Logger        = require "cosy.logger"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"
local Ffi           = require "ffi"
local Websocket     = require "websocket"

local i18n   = I18n.load (require "cosy.daemon-i18n")
i18n._locale = Configuration.locale._

local Daemon = {}

Daemon.libraries = {}

function Daemon.request (message)
  if message == "daemon-stop" then
    Daemon.stop ()
    return {
      success = true,
    }
  end
  local server = message.server
  local lib    = Daemon.libraries [server]
  if not lib then
    lib = Library.connect (server)
    if not lib then
      return {
        success = false,
        error   = {
          _ = i18n ["server:unreachable"],
        },
      }
    end
    Daemon.libraries [server] = lib
  end
  local method = lib [message.operation]
  local result, err = method (message.parameters, message.try_only)
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
  return result
end

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
    interface = Configuration.daemon.interface._,
    port      = Configuration.daemon.port._,
    protocols = {
      cosy = function (ws)
        while true do
          local message = ws:receive ()
          if not message then
            ws:close ()
            return
          end
          message      = Value.decode (message)
          local result = Daemon.request (message)
          result       = Value.expression (result)
          ws:send (result)
        end
      end
    }
  }
  Scheduler.addserver = addserver
  Logger.debug {
    _    = i18n ["websocket:listen"],
    host = Configuration.daemon.interface._,
    port = Configuration.daemon.port._,
  }
  do
    local daemonfile = Configuration.daemon.data_file._
    local file       = io.open (daemonfile, "w")
    file:write (Value.expression {
      interface = Configuration.daemon.interface._,
      port      = Configuration.daemon.port._,
    })
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = daemonfile })
  end
  do
    Ffi.cdef [[ unsigned int getpid (); ]]
    local pidfile = Configuration.daemon.pid_file._
    local file    = io.open (pidfile, "w")
    file:write (Ffi.C.getpid ())
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = pidfile })
  end
  Scheduler.loop ()
end

function Daemon.stop ()
  Scheduler.addthread (function ()
    Scheduler.sleep (1)
    os.remove (Configuration.daemon.data_file._)
    os.remove (Configuration.daemon.pid_file ._)
    os.exit   (0)
  end)
end

return Daemon
