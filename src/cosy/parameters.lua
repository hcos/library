local loader        = require "cosy.loader"

local Internal      = loader.repository.of (loader.configuration) .internal
local Parameters    = setmetatable ({}, {
  __index = function (_, key)
    return loader.configuration.data [key]
  end,
})

function Parameters.check (request, parameters)
  request    = request    or {}
  parameters = parameters or {}
  local reasons = {}
  local checked = {}
  for _, field in ipairs { "required", "optional" } do
    for key, parameter in pairs (parameters [field] or {}) do
      local value = request [key]
      if field == "required" and value == nil then
        reasons [#reasons+1] = {
          _   = "check:missing",
          key = key,
        }
      elseif value ~= nil then
        for i = 1, loader.repository.size (parameter.check) do
          local ok, reason = parameter.check [i]._ {
            parameter = parameter,
            request   = request,
            key       = key,
          }
          checked [key] = true
          if not ok then
            reason.key           = key
            reasons [#reasons+1] = reason
            break
          end
        end
      end
    end
  end
  for key in pairs (request) do
    if not checked [key] then
      loader.logger.warning {
        _   = "check:no-check",
        key = key,
      }
    end
  end
  if #reasons ~= 0 then
    error {
      _          = "check:error",
      reasons    = reasons,
    }
  end
end

-- String
-- ------
do
  Internal.data.string = {
    min_size = 0,
    max_size = math.huge,
  }
  local checks = Internal.data.string.check
  checks [1] = function (t)
    local value = t.request [t.key]
    return  type (value) == "string"
        or  nil, {
              _   = "check:is-string",
            }
  end
  checks [2] = function (t)
    local value = t.request [t.key]
    local size  = t.parameter.min_size._
    return  #value >= size
        or  nil, {
              _     = "check:min-size",
              count = size,
            }
  end
  checks [3] = function (t)
    local value = t.request [t.key]
    local size  = t.parameter.max_size._
    return  #value <= size
        or  nil, {
              _     = "check:max-size",
              count = size,
            }
  end
end

-- Trimmed String
-- --------------
do
  Internal.data.trimmed = {
    [loader.repository.refines] = {
      loader.configuration.data.string,
    }
  }
  local checks = Internal.data.trimmed.check
  checks [2] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    request [key] = value:trim ()
    return true
  end
  checks [3] = Internal.data.string.check [2]._
  checks [4] = Internal.data.string.check [3]._
end

-- Username
-- --------
do
  Internal.data.username = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    }
  }
  local checks = Internal.data.username.check
  checks [loader.repository.size (checks)+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%w[%w%-_]+$"
        or  nil, {
              _        = "check:username:alphanumeric",
              username = value,
            }
  end
end

-- Password
-- --------
do
  Internal.data.password = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    }
  }
end

-- Email
-- -----
do
  Internal.data.email = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    }
  }
  local checks = Internal.data.email.check
  checks [loader.repository.size (checks)+1] = function (t)
    local value   = t.request [t.key]
    local pattern = "^.*@[%w%.%%%+%-]+%.%w%w%w?%w?$"
    return  value:find (pattern)
        or  nil, {
              _     = "check:email:pattern",
              email = value,
            }
  end
end

-- Name
-- ----
do
  Internal.data.name = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    }
  }
end

-- Locale
-- ------
do
  Internal.data.locale = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    }
  }
  local checks = Internal.data.locale.check
  checks [loader.repository.size (checks)+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%a%a$"
        or  value:find "^%a%a_%a%a$"
        or  nil, {
              _      = "check:locale:pattern",
              locale = value,
            }
  end
end

-- Terms of Services Digest
-- ------------------------
do
  Internal.data.tos_digest = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    },
    min_size = 128,
    max_size = 128,
  }
  local checks = Internal.data.tos_digest.check
  checks [loader.repository.size (checks)+1] = function (t)
    t.request [t.key] = t.request [t.key]:lower ()
    return  true
  end
  checks [loader.repository.size (checks)+1] = function (t)
    local value   = t.request [t.key]
    local pattern = "^%x+$"
    return  value:find (pattern)
        or  nil, {
              _          = "check:tos_digest:pattern",
              tos_digest = value,
            }
  end
  checks [loader.repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    local tos = loader.methods.tos { locale = request.locale }
    return  tos.tos_digest == value
        or  nil, {
              _          = "check:tos_digest:incorrect",
              tos_digest = value,
            }
  end
end

-- Token
-- -----
do
  Internal.data.token = {
    [loader.repository.refines] = {
      loader.configuration.data.trimmed,
    },
  }
  local checks = Internal.data.token.check
  checks [loader.repository.size (checks)+1] = function (t)
    local request    = t.request
    local key        = t.key
    local value      = request [key]
    local ok, result = pcall (loader.token.decode, value)
    if not ok then
      return nil, {
        _ = "check:token:invalid",
      }
    end
    request [key] = result.contents
    return  true
  end
end

-- Administration token
-- --------------------
do
  Internal.data.token.administration = {
    [loader.repository.refines] = {
      loader.configuration.data.token,
    },
  }
  local checks = Internal.data.token.administration.check
  checks [loader.repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.type == "administration"
        or  nil, {
              _ = "check:token:invalid",
            }
  end
  checks [loader.repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.passphrase == loader.server.passphrase
        or  nil, {
              _ = "check:token:invalid",
            }
  end
end

-- Validation token
-- ----------------
do
  Internal.data.token.validation = {
    [loader.repository.refines] = {
      loader.configuration.data.token,
    },
  }
  local checks = Internal.data.token.validation.check
  checks [loader.repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.type == "validation"
        or  nil, {
              _ = "check:token:invalid",
            }
  end
end

-- Authentication Token
-- --------------------
do
  Internal.data.token.authentication = {
    [loader.repository.refines] = {
      loader.configuration.data.token,
    },
  }
  local checks = Internal.data.token.authentication.check
  checks [loader.repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.type == "authentication"
        or  nil, {
              _ = "check:token:invalid",
            }
  end
  checks [loader.repository.size (checks)+1] = function (t)
    local store    = loader.store.new ()
    local username = t.request [t.key].username
    local user     = store.users [username]
    return  user
       and  user.type   == loader.methods.Type.user
       and  user.status == loader.methods.Status.active
        or  nil, {
              _ = "check:token:invalid",
            }
  end
end

return Parameters