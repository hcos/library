local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Library       = require "cosy.library"
local Value         = require "cosy.value"

Configuration.load {
  "cosy.daemon",
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.daemon",
  "cosy.server",
}
i18n._locale = Configuration.locale

local libraries = {}

return function (message)
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
  local lib    = libraries [server]
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
    libraries [server] = lib
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
  return Value.expression (result)
end
