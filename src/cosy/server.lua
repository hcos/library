local loader  = require "cosy.loader"

local Server = {}

function Server.request (message)
  local i18n = loader.i18n
  local function translate (x)
    i18n (x)
    return x
  end
  local decoded, request = pcall (loader.value.decode, message)
  if not decoded or type (request) ~= "table" then
    return loader.value.expression (translate {
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
  local Methods    = loader.methods
  local method     = Methods [operation]
  if not method then
    return loader.value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _      = "rpc:no-operation",
        reason = operation,
      },
    })
  end
  local result, err = method (parameters or {})
  if not result then
    return loader.value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = err,
    })
  end
  return loader.value.expression (translate {
    identifier = identifier,
    success    = true,
    response   = result,
  })
end

function Server.start ()
  -- Generate administration token:
  Server.passphrase = loader.digest (loader.random ())
  Server.token      = loader.token.administration ()
  loader.logger.info {
    _     = "administration",
    token = Server.token,
  }
  -- Run websocket server:
  local internal  = loader.repository.of (loader.configuration) .internal
  local scheduler = loader.scheduler
  local websocket = loader "websocket"
  local copas     = loader "copas"
  local addserver = copas.addserver
  copas.addserver = function (s, f)
    local ok, port = s:getsockname ()
    if ok then
      internal.websocket.port = port
    end
    addserver (s, f)
  end
  Server.ws = websocket.server.copas.listen {
    interface = loader.configuration.websocket.interface._,
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
  copas.addserver = addserver
  loader.logger.debug {
    _    = "websocket:listening",
    host = loader.configuration.websocket.host._,
    port = loader.configuration.websocket.port._,
  }
  loader.nginx.start ()
  scheduler.loop ()
end

function Server.stop ()
  loader.scheduler.addthread (function ()
    loader.scheduler.sleep (1)
    Server.ws:close   ()
    loader.nginx.stop ()
    os.exit (0)
  end)
end

function Server.update ()
  loader.nginx.update ()
end

return Server