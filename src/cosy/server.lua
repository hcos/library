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
  -- Generate administration token:
  Server.passphrase = Digest (Random ())
  Server.token      = Token.administration ()
  Logger.info {
    _     = "administration",
    token = Server.token,
  }
  -- Run websocket server:
  local internal  = Repository.of (Configuration) .internal
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
          if message then
            ws:send (Server.request (message))
          else
            ws:close ()
            return
          end
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
  Scheduler.addthread (function ()
    Scheduler.sleep (1)
    Server.ws:close   ()
    Nginx.stop ()
    os.exit (0)
  end)
end

function Server.update ()
  Nginx.update ()
end

return Server