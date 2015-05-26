package.path  = package.path:gsub ("'", "")
  .. ";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;"

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Methods       = require "cosy.methods"
local Nginx         = require "cosy.nginx"
local Random        = require "cosy.random"
local Repository    = require "cosy.repository"
local Scheduler     = require "cosy.scheduler"
local Token         = require "cosy.token"
local Value         = require "cosy.value"
local Websocket     = require "websocket"
local Lfs           = require "lfs"
local Socket        = require "socket"
      Socket.unix   = require "socket.unix"

local datafile = Configuration.server.data_file._

local Server = {}

function Server.request (message)
  local function translate (x)
    I18n (x)
    return x
  end
  local decoded, request = pcall (Value.decode, message)
  if not decoded or type (request) ~= "table" then
    return Value.expression (translate {
      success = false,
      error   = {
        _      = "rpc:invalid",
        reason = message,
      },
    })
  end
  local identifier = request.identifier
  local operation  = request.operation
  local parameters = request.parameters
  local try_only   = request.try_only
  local method     = Methods [operation]
  if not method then
    return Value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _      = "rpc:no-operation",
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
  os.remove (datafile)
  Server.passphrase = Digest (Random ())
  Server.token      = Token.administration (Server)
  -- Set www path:
  local internal = Repository.of (Configuration) .internal
  local main     = package.searchpath ("cosy", package.path)
  if main:sub (1, 1) == "." then
    main = Lfs.currentdir () .. "/" .. main
  end
  internal.http.www = main:sub (1, #main-4) .. "/../www/"
  local addserver = Scheduler.addserver
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      internal.server.port = port
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
    _    = "server:listening",
    host = Configuration.server.interface._,
    port = Configuration.server.port._,
  }
  local file = io.open (datafile, "w")
  file:write (Value.expression {
    token     = Server.token,
    interface = Configuration.server.interface._,
    port      = Configuration.server.port._,
  })
  file:close ()
  os.execute ([[ chmod 0600 %{file} ]] % { file = datafile })
  Nginx.start ()
  Scheduler.loop ()
end

function Server.stop ()
  Server.ws:close ()
  Scheduler.addthread (function ()
    Nginx.stop ()
    os.remove (datafile)
    os.exit   (0)
  end)
  return true
end

return Server