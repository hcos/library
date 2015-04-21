-- Methods
-- =======

-- This module defines the methods exposed by CosyVerif.
-- Methods use the standard [JSON Web Tokens](http://jwt.io/) to authenticate users.
-- Each method takes two parameters: the decoded token contents,
-- and the request itself.
-- 
-- The `cosy.methods` module returns a table containing several variants
-- of the API:
--
-- * `cosy.methods.Localized` exports them as library functions to be used within
--   the server. The `request` parameter is juste a plain table that is
--   automatically converted to a `Request`. Responses and errors are localized
--   using the locale chosen by the user.
--
-- Internally, the module makes use of `cosy.data` to represent its data,
-- and `redis` to store and retrieve them. Any data or subdata can have
-- an expiration date (either handled by `redis` or by `cosy.data`). After
-- expiration, its value and subdata disappear.

-- The `Methods` table contains all available methods.
local Methods  = {}
-- The `Token` table contains utility functions for JSON Web Tokens.
local Token    = {}
-- The `Redis` table contains the `Redis.transaction` wqrapper.
local Redis  = {}

-- Dependencies
-- ------------
--
-- This module depends on the following modules:
local loader        = require "cosy.loader"

local Repository    = loader.repository
local Store         = loader.store
local Configuration = loader.configuration
local Internal      = Repository.of (Configuration) .internal
local Parameters    = Configuration.data

Internal.redis.key = {
  users  = "user:%{key}",
  emails = "email:%{key}",
  tokens = "token:%{key}",
}

local Status = setmetatable ({
  inactive  = "inactive",
  active    = "active",
  suspended = "suspended",
}, {
  __index = assert,
})

local Type = setmetatable ({
  user = "user",
}, {
  __index = assert,
})

-- Check
-- -------

local function check (request, parameters)
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
        for i = 1, #parameter.check do
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

-- Methods
-- -------

-- ### Information

function Methods.information ()
  return {
    name = Configuration.server.name._,
  }
end

-- ### Terms of Service

function Methods.tos (request)
  check (request, {
    optional = {
      token  = Parameters.token,
      locale = Parameters.locale,
    },
  })
  local locale = Configuration.locale.default._
  if request.locale then
    locale = request.locale or locale
  end
  if request.token then
    locale = request.token.locale or locale
  end
  local tos = loader.i18n {
    _      = "tos",
    locale = locale,
  }
  return {
    tos        = tos,
    tos_digest = loader.digest (tos),
  }
end

-- ### User Creation

function Methods.create_user (request, store)
  check (request, {
    required = {
      username   = Parameters.username,
      password   = Parameters.password,
      email      = Parameters.email,
      tos_digest = Parameters.tos_digest,
      locale     = Parameters.locale,
    },
  })
  if store.emails [request.email] then
    error {
      _     = "create-user:email-exists",
      email = request.email,
    }
  end
  if store.users [request.username] then
    error {
      _        = "create-user:username-exists",
      username = request.username,
    }
  end
  store.emails [request.email] = {
    username  = request.username,
  }
  store.users [request.username] = {
    type        = Type.user,
    status      = Status.active,
    username    = request.username,
    email       = request.email,
    password    = loader.password.hash (request.password),
    locale      = request.locale,
    tos_digest  = request.tos_digest,
    reputation  = Configuration.reputation.at_creation._,
    access      = {
      public = true,
    },
    contents    = {},
  }
  return Token.authentication (store.users [request.username])
end

-- ### Authentication

function Methods.authenticate (request, store)
  check (request, {
    required = {
      username = Parameters.username,
      password = Parameters.password,
    },
  })
  local user = store.users [request.username]
  if not user
  or user.type   ~= Type.user
  or user.status ~= Status.active
  or not loader.password.verify (request.password, user.password) then
    error {
      _ = "authenticate:failure",
    }
  end
  if loader.password.is_too_cheap (user.password) then
    user.password = loader.password.hash (request.password)
  end
  return Token.authentication (user)
end

-- ### Reset password

function Methods.reset_user (request, store)
  check (request, {
    required = {
      email = Parameters.email,
    },
  })
  local email = store.emails [request.email]
  if not email then
    return true
  end
  local user = store.users [email.username]
  if not user
  or user.type   ~= Type.user then
    return true
  end
  local token = Token.validation (user)
  local sent  = loader.email.send {
    locale  = user.locale,
    from    = {
      _     = "email:reset_account:from",
      name  = Configuration.server.name._,
      email = Configuration.server.email._,
    },
    to      = {
      _     = "email:reset_account:to",
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = "email:reset_account:subject",
      servername = Configuration.server.name._,
      username   = user.username,
    },
    body    = {
      _          = "email:reset_account:body",
      username   = user.username,
      validation = token,
    },
  }
  if sent then
    user.status     = Status.suspended
    user.validation = token
    return true
  else
    error {
      _ = "reset-user:retry",
    }
  end
end

-- ### Suspend User

function Methods.suspend_user (request, store)
  check (request, {
    required = {
      username = Parameters.username,
      token    = Parameters.token.authentication,
    },
  })
  local target = store.users [request.username]
  if target.type ~= Type.user then
    error {
      _        = "suspend:not-user",
      username = request.username,
    }
  end
  local user       = store.users [request.token.username]
  local reputation = Configuration.reputation.suspend._
  if user.reputation < reputation then
    error {
      _        = "suspend:not-enough",
      owned    = user.reputation,
      required = reputation
    }
  end
  user.reputation = user.reputation - reputation
  target.status   = Status.suspended
  return true
end

-- ### User Deletion

function Methods.delete_user (request, store)
  check (request, {
    required = {
      token = Parameters.token.authentication,
    },
  })
  local user = store.users [request.token.username]
  store.emails [user.email   ] = nil
  store.users  [user.username] = nil
  return true
end

-- Checks
-- ------

do
  local checks

  Internal.data.string = {
    min_size = 0,
    max_size = math.huge,
  }
  
  checks = Internal.data.string.check
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
  

  Internal.data.trimmed = {
    [Repository.refines] = {
      Configuration.data.string,
    }
  }
  checks = Internal.data.trimmed.check
  checks [2] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    request [key] = value:trim ()
    return true
  end
  checks [3] = Internal.data.string.check [2]._
  checks [4] = Internal.data.string.check [3]._

  Internal.data.username = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
  checks = Internal.data.username.check
  checks [#checks+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%w[%w%-_]+$"
        or  nil, {
              _        = "check:username:alphanumeric",
              username = value,
            }
  end

  Internal.data.password = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }

  Internal.data.email = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
  checks = Internal.data.email.check
  checks [#checks+1] = function (t)
    local value   = t.request [t.key]
    local pattern = "^.*@[%w%.%%%+%-]+%.%w%w%w?%w?$"
    return  value:find (pattern)
        or  nil, {
              _     = "check:email:pattern",
              email = value,
            }
  end

  Internal.data.name = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }

  Internal.data.locale = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
  checks = Internal.data.locale.check
  checks [#checks+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%a%a$"
        or  value:find "^%a%a_%a%a$"
        or  nil, {
              _      = "check:locale:pattern",
              locale = value,
            }
  end

  Internal.data.tos_digest = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    },
    min_size = 64,
    max_size = 64,
  }
  checks = Internal.data.tos_digest.check
  checks [#checks+1] = function (t)
    t.request [t.key] = t.request [t.key]:lower ()
    return  true
  end
  checks [#checks+1] = function (t)
    local value   = t.request [t.key]
    local pattern = "^%x+$"
    return  value:find (pattern)
        or  nil, {
              _          = "check:tos_digest:pattern",
              tos_digest = value,
            }
  end
  checks [#checks+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    local tos = Methods.tos { locale = request.locale }
    return  tos.tos_digest == value
        or  nil, {
              _          = "check:tos_digest:incorrect",
              tos_digest = value,
            }
  end

  Internal.data.token = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    },
  }
  checks = Internal.data.token.check
  checks [#checks+1] = function (t)
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

  Internal.data.token.validation = {
    [Repository.refines] = {
      Configuration.data.token,
    },
  }
  checks = Internal.data.token.validation.check
  checks [#checks+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.type == "validation"
        or  nil, {
              _ = "check:token:invalid",
            }
  end

  Internal.data.token.authentication = {
    [Repository.refines] = {
      Configuration.data.token,
    },
  }
  checks = Internal.data.token.authentication.check
  checks [#checks+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.type == "authentication"
        or  nil, {
              _ = "check:token:invalid",
            }
  end
  checks [#checks+1] = function (t)
    local store    = Store.new ()
    local username = t.request [t.key].username
    local user     = store.users [username]
    return  user
       and  user.type   == Type.user
       and  user.status == Status.active
        or  nil, {
              _ = "check:token:invalid",
            }
  end
end

-- Token
--------

function Token.validation (data)
  local now    = loader.time ()
  local result = {
    contents = {
      type     = "validation",
      username = data.username,
      email    = data.email,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.validation._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:validation",
    jti      = loader.digest (tostring (now + loader.random ())),
  }
  return loader.token.encode (result)
end

function Token.authentication (data)
  local now    = loader.time ()
  local result = {
    contents = {
      type     = "authentication",
      username = data.username,
      locale   = data.locale,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.authentication._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:authentication",
    jti      = loader.digest (tostring (now + loader.random ())),
  }
  return loader.token.encode (result)
end

Internal.redis.retry = 2

for k, f in pairs (Methods) do
  Methods [k] = function (request)
    for _ = 1, Configuration.redis.retry._ do
      local ok, result = pcall (function (request)
        local store  = Store.new ()
        local result = f (request, store)
        Store.commit (store)
        return result
      end, request)
      if ok then
        return result or true
      elseif result ~= Store.Error then
        return nil, result
      end
    end
    return nil, {
      _ = "redis:unavailable",
    }
  end
end

return Methods