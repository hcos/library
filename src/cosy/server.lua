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

local Server = {
  Messages = {
    stop   = "Server, stop!",
    update = "Server, update!",
  },
}

local tokenfile  = Configuration.config.server.token_file._
local socketfile = Configuration.config.server.socket_file._

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
  os.remove (tokenfile)
  Server.passphrase = Digest (Random ())
  Server.token      = Token.administration (Server)
  local file = io.open (tokenfile, "w")
  file:write (Value.expression (Server.token))
  file:close ()
  os.execute ([[ chmod 0600 %{file} ]] % { file = tokenfile })
  
  local internal = Repository.of (Configuration) .internal
  local main     = package.searchpath ("cosy", package.path)
  if main:sub (1, 1) == "." then
    main = Lfs.currentdir () .. "/" .. main
  end
  internal.http.www = main:sub (1, #main-4) .. "/../www/"

  os.remove (socketfile)
  local socket = Socket.unix ()
  socket:bind   (socketfile)
  socket:listen (32)
  os.execute ([[ chmod 0700 %{file} ]] % { file = socketfile })
  Scheduler.addserver (socket, function (connection)
    local ok, err = pcall (function ()
      while true do
        local message = connection:receive "*l"
        if     message == Server.Messages.stop then
          Server.stop ()
          return
        elseif message == Server.Messages.update then
          Server.update ()
          return
        elseif not message then
          connection:close ()
          return
        end
      end
    end)
    if not ok then
      connection:send (err)
    end
  end)
  
  local addserver = Scheduler.addserver
  Scheduler.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      internal.websocket.port = port
    end
    addserver (s, f)
  end
  Server.ws = Websocket.server.copas.listen {
    interface = Configuration.websocket.interface._,
    port      = 0,
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
    _    = "websocket:listening",
    host = Configuration.websocket.host._,
    port = Configuration.websocket.port._,
  }
  Nginx.start ()
  Scheduler.loop ()
end

function Server.stop ()
  os.remove (tokenfile )
  os.remove (socketfile)
  Server.ws:close ()
  Nginx.stop ()
  os.exit (0)
end

function Server.update ()
  Nginx.update ()
end

return Server