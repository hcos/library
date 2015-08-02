local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Methods       = require "cosy.methods"
local Store         = require "cosy.store"
local Value         = require "cosy.value"

Configuration.load "cosy.server"

local i18n   = I18n.load "cosy.server"
i18n._locale = Configuration.locale

local function deproxify (t)
  if type (t) ~= "table" then
    return t
  else
    t = Store.export (t)
    local result = {}
    for k, v in pairs (t) do
      assert (type (k) ~= "table")
      result [k] = deproxify (v)
    end
    return result
  end
end

local function call_method (method, parameters, try_only)
  for _ = 1, Configuration.redis.retry or 1 do
    local store  = Store.new ()
    store = Store.specialize (store, Configuration.server.token)
    local err
    local ok, result = xpcall (function ()
      local r = method (parameters, store, try_only)
      if not try_only then
        Store.commit (store)
      end
      return r
    end, function (e)
      if tostring (e):match "ERR MULTI" then
        store.__redis:discard ()
      elseif type (e  ) == "table"
         and type (e._) == "table"
         and e._._key   ~= "redis:retry" then
        err = e
      else
        Logger.debug {
          _      = i18n ["server:exception"],
          reason = Value.expression (e) .. " => " .. debug.traceback (),
        }
      end
    end)
    if ok then
      return deproxify (result) or true
    elseif err then
      return nil, err
    end
  end
  return nil, {
    _ = i18n ["error:internal"],
  }
end

local function call_parameters (method, parameters)
  parameters.__DESCRIBE = true
  local _, result = pcall (method, parameters)
  return result
end

return function (message)
  local decoded, request = pcall (Value.decode, message)
  if not decoded or type (request) ~= "table" then
    return Value.expression (i18n {
      success = false,
      error   = {
        _ = i18n ["message:invalid"],
      },
    })
  end
  local identifier      = request.identifier
  local operation       = request.operation
  local parameters      = request.parameters or {}
  local try_only        = request.try_only
  local parameters_only = false
  local method          = Methods
  if operation:sub (-1) == "?" then
    operation       = operation:sub (1, #operation-1)
    parameters_only = true
  end
  for name in operation:gmatch "[^:]+" do
    if method ~= nil then
      name = name:gsub ("-", "_")
      method = method [name]
    end
  end
  if not method then
    return Value.expression (i18n {
      identifier = identifier,
      success    = false,
      error      = {
        _         = i18n ["server:no-operation"],
        operation = request.operation,
      },
    })
  end
  local result, err
  if parameters_only then
    result      = call_parameters (method, parameters)
  else
    result, err = call_method (method, parameters, try_only)
  end
  if result then
    result = i18n {
      identifier = identifier,
      success    = true,
      response   = result,
    }
  else
    result = i18n {
      identifier = identifier,
      success    = false,
      error      = err,
    }
  end
  return Value.expression (result)
end
