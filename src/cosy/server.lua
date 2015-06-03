package.path  = package.path:gsub ("'", "")
  .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;"

local Configuration = require "cosy.configuration"

local Internal  = Configuration / "default"
Internal.server = {
  interface = "127.0.0.1",
  port      = 0,
  data_file = os.getenv "HOME" .. "/.cosy/server.data",
  log_file  = os.getenv "HOME" .. "/.cosy/server.log",
  pid_file  = os.getenv "HOME" .. "/.cosy/server.pid",
}
if _G ["cosy:configuration-only"] then
  return
end

local Digest        = require "cosy.digest"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Methods       = require "cosy.methods"
local Nginx         = require "cosy.nginx"
local Random        = require "cosy.random"
local Scheduler     = require "cosy.scheduler"
local Token         = require "cosy.token"
local Value         = require "cosy.value"
local Websocket     = require "websocket"
local Ffi           = require "ffi"
local Lfs           = require "lfs"
local Socket        = require "socket"
      Socket.unix   = require "socket.unix"

local i18n   = I18n.load "cosy.server-i18n"
i18n._locale = Configuration.locale._

local Server = {}

function Server.request (message)
  local function translate (x)
    i18n (x)
    return x
  end
  local decoded, request = pcall (Value.decode, message)
  if not decoded or type (request) ~= "table" then
    return Value.expression (translate {
      success = false,
      error   = {
        _ = i18n ["message:invalid"],
      },
    })
  end
  local identifier = request.identifier
  local operation  = request.operation
  local parameters = request.parameters
  local try_only   = request.try_only
  local method     = Methods
  for name in operation:gmatch "[^:]+" do
    if method ~= nil then
      method = method [name]
    end
  end
  if not method then
    return Value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _      = i18n ["message:no-operation"],
        reason = operation,
      },
    })
  end
  local result, err = method (parameters or {}, try_only)
  if not result then
    return Value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = err,
    })
  end
  return Value.expression (translate {
    identifier = identifier,
    success    = true,
    response   = result,
  })
end

function Server.start ()
  Server.passphrase = Digest (Random ())
  Server.token      = Token.administration (Server)
  -- Set www path:
  local main = package.searchpath ("cosy.server", package.path)
  if main:sub (1, 1) == "." then
    main = Lfs.currentdir () .. "/" .. main
  end
  Internal.http.www = main:gsub ("cosy/server.lua", "cosy/www/")
  local addserver = Scheduler.addserver
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      Configuration.server.port = port
    end
    addserver (s, f)
  end
  Server.ws = Websocket.server.copas.listen {
    interface = Configuration.server.interface._,
    port      = Configuration.server.port._,
    protocols = {
      cosy = function (ws)
        while true do
          local message = ws:receive ()
          if not message then
            ws:close ()
            return
          end
          ws:send (Server.request (message))
        end
      end
    }
  }
  Scheduler.addserver = addserver
  Logger.debug {
    _    = i18n ["websocket:listen"],
    host = Configuration.server.interface._,
    port = Configuration.server.port._,
  }
  do
    local datafile = Configuration.server.data_file._
    local file     = io.open (datafile, "w")
    file:write (Value.expression {
      token     = Server.token,
      interface = Configuration.server.interface._,
      port      = Configuration.server.port._,
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
    local pidfile = Configuration.server.pid_file._
    local file    = io.open (pidfile, "w")
    file:write (Ffi.C.getpid ())
    file:close ()
    os.execute ([[ chmod 0600 {{{file}}} ]] % { file = pidfile })
  end
  Scheduler.loop ()
end

function Server.stop ()
  os.remove (Configuration.server.data_file._)
  os.remove (Configuration.server.pid_file ._)
  Scheduler.addthread (function ()
    Scheduler.sleep (1)
    Nginx.stop ()
    os.exit   (0)
  end)
end

return Server
