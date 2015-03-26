local coevas        = require "copas.ev"
coevas:make_default ()
local Configuration = require "cosy.configuration"
local Platform      = require "cosy.platform"
local Methods       = require "cosy.methods"

local function translate (x)
  x.locale = x.locale or Configuration.locale._
  for _, v in pairs (x) do
    if type (v) == "table" and not getmetatable (v) then
      local vl  = v.locale
      v.locale  = x.locale
      v.message = translate (v)
      v.locale  = vl
    end
  end
  if x._ then
    x.message = Platform.i18n.translate (x._, x)
  end
  return x
end

local function request (message)
  local decoded, request = Platform.table.decode (message)
  if not decoded then
    return Platform.table.encode (translate {
      success = false,
      error   = {
        _      = "rpc:format",
        reason = message,
      },
    })
  end
  local identifier = request.identifier
  local operation  = request.operation
  local parameters = request.parameters
  local method     = Methods [operation]
  if not method then
    return Platform.table.encode (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _      = "rpc:no-operation",
        reason = operation,
      },
    })
  end
  local called, result = pcall (method, parameters or {})
  if not called then
    return Platform.table.encode (translate {
      identifier = identifier,
      success    = false,
      error      = result,
    })
  end
  return Platform.table.encode (translate {
    identifier = identifier,
    success    = true,
    response   = result,
  })
end

local copas     = require "copas"
local websocket = require "websocket"

Platform:register ("email", function ()
  Platform.email = {}
  Platform.email.last_sent = {}
  Platform.email.send = function (t)
    Platform.email.last_sent [t.to.email] = t
  end
end)

websocket.server.copas.listen {
  interface = Configuration.server.host._,
  port      = Configuration.server.port._,
  protocols = {
    cosy = function (client)
      while true do
        local message = client:receive ()
        if message then
          local result = request (message)
          if result then
            client:send (result)
          end
        else
          client:close ()
          return
        end
      end
    end,
  },
  default = function (client)
    client:send "'cosy' is the only supported protocol"
    client:close ()
  end
}

copas.loop ()