local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Value         = require "cosy.value"
local Layer         = require "layeredata"

Configuration.load "cosy.parameters"

local i18n   = I18n.load "cosy.parameters"
i18n._locale = Configuration.locale

local Parameters = setmetatable ({}, {
  __index = function (_, key)
    return Configuration.data [key]
  end,
})

function Parameters.check (store, request, parameters)
  parameters = parameters or {}
  if request.__DESCRIBE then
    local result = {
      required = {},
      optional = {},
    }
    local locale = Configuration.locale.default
    if request.locale then
      locale = request.locale or locale
    end
    for _, part in ipairs { "required", "optional" } do
      for k, v in pairs (parameters [part] or {}) do
        local name = {}
        for i = 2, #v.__keys do
          name [#name+1] = v.__keys [i]
        end
        name = table.concat (name, ":")
        local ok, err = pcall (function ()
          result [part] [k] = {
            type        = name,
            description = i18n [name] % {
              locale = locale,
            }
          }
        end)
        if not ok then
          Logger.warning {
            _      = i18n ["translation:failure"],
            reason = err,
          }
          result [part] [k] = {
            type        = name,
            description = "(missing description)",
          }
        end
      end
    end
    error (result)
  end
  local reasons = {}
  local checked = {}
  for _, field in ipairs { "required", "optional" } do
    for key, parameter in pairs (parameters [field] or {}) do
      local value = request [key]
      if field == "required" and value == nil then
        reasons [#reasons+1] = {
          _   = i18n ["check:not-found"],
          key = key,
        }
      elseif value ~= nil then
        for i = 1, Layer.size (parameter.checks) do
          local ok, reason = parameter.checks [i] {
            parameter = parameter,
            request   = request,
            key       = key,
            store     = store,
          }
          checked [key] = true
          if not ok then
            reason.parameter     = key
            reasons [#reasons+1] = reason
            break
          end
        end
      end
    end
  end
  -- Special case: authentication can be added in any request
  -- without issuing an error...
  if request.authentication and not checked.authentication then
    request.authentication = nil
  end
  for key in pairs (request) do
    if not checked [key] then
      Logger.warning {
        _       = i18n ["check:no-check"],
        key     = key,
        request = Value.expression (request),
      }
      request [key] = nil
    end
  end
  if #reasons ~= 0 then
    error {
      _       = i18n ["check:error"],
      reasons = reasons,
    }
  end
end

return Parameters