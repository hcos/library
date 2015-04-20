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
-- The `Parameters` table contains several types of parameters, and defines
-- for each one several checking functions.
local Parameters = {}

-- Dependencies
-- ------------
--
-- This module depends on the following modules:
local loader        = require "cosy.loader"

local Repository    = loader.repository
local Store         = loader.store
local Configuration = loader.configuration
local Internal      = Repository.of (Configuration) .internal

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

-- Methods
-- -------
--
-- Methods use the standard [JSON Web Tokens](http://jwt.io/) to authenticate users.
-- Each method takes two parameters: the decoded token contents,
-- and the request parameters.

-- In order to run the methods, we first have to load some dependencies:
--
-- * the `loader` (here in test mode);
-- * the `Methods` (localized);
-- * the `Configuration`, with some predefined values, and a reduced expiration
--   delay to reduce the time taken by the tests.
--
--    > Configuration = require "cosy.configuration"
--    > loader      = require "cosy.loader"
--    > Methods       = require "cosy.methods"
--    > Configuration.data.password.time        = 0.001 -- second
--    > Configuration.token.secret              = "secret"
--    > Configuration.token.algorithm           = "HS256"
--    > Configuration.server.name               = "CosyTest"
--    > Configuration.server.email              = "test@cosy.org"
--    > Configuration.expiration.account        = 2 -- second
--    > Configuration.expiration.validation     = 2 -- second
--    > Configuration.expiration.authentication = 2 -- second

-- ### Information
--
-- The `information` method returns some useful or useless information about
-- the running Cosy server.

function Methods.information ()
  return {
    name = Configuration.server.name._,
  }
end

-- ### Terms of Service
--
-- In order to create an account or authenticate, users of CosyVerif must
-- accept the "Terms of Service". Because of internationalization, we **must**
-- provide to users the "Terms of Service" in their language
-- (or a fallback one), and they **must** accept it by providing its digest.
--
-- The `tos` method returns the "Terms of Service" in a selected locale
-- (the user's one, or a locale provided in the request), and its computed
-- digest, that can be used later for acceptation.

function Methods.tos (request)
  Parameters.check (request, {
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

-- User creation requires several parameters in its `request`:
--
-- * a `username`, that is unique on the server;
-- * a `password`, that is used to authenticate the user;
-- * an `email` address, where the validation token is sent;
-- a `tos_digest`, corresponding to the terms of service accepted by the user;
-- a `locale`, that is used to localize all the messages sent back to the user.

function Methods.create_user (request, store)
  request.required = {
    username   = Parameters.username,
    password   = Parameters.password,
    email      = Parameters.email,
    tos_digest = Parameters.tos_digest,
    locale     = Parameters.locale,
  }
  Parameters.check (request)
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
    access      = {
      public = true,
    },
    contents    = {},
  }
  return Token.authentication (store.users [request.username])
end

-- ### Authentication

function Methods.authenticate (request, store)
  request.required = {
    username = Parameters.username,
    password = Parameters.password,
  }
  Parameters.check (request)
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




function Methods.reset_user (_, request)
  request.required = {
    email = Parameters.email,
  }
  Parameters.check (request)
  local username = Redis.transaction ({
    email = Configuration.redis.key.email._ % { email = request.email },
  }, function (p)
    if not p.email
    or not p.email.username then
      error {}
    end
    return p.email.username
  end)
  local data = Redis.transaction ({
    data  = Configuration.redis.key.user._ % { username = username },
  }, function (p)
    if not p.data
    or p.data.status == Status.suspended
    then
      error {}
    end
    p.data.status = Status.inactive
    return p.data
  end)
  loader.email.send {
    locale  = data.locale,
    from    = {
      _     = "email:new_account:from",
      name  = Configuration.server.name._,
      email = Configuration.server.email._,
    },
    to      = {
      _     = "email:new_account:to",
      name  = data.name,
      email = data.email,
    },
    subject = {
      _          = "email:new_account:subject",
      servername = Configuration.server.name._,
      username   = data.username,
    },
    body    = {
      _          = "email:new_account:body",
      username   = data.username,
      validation = validation_token,
      tos        = {
        _ = "tos",
      },
    },
  }
  loader.email.send {
    locale  = data.locale,
    from    = {
      _     = "email:reset_account:from",
      name  = Configuration.server.name._,
      email = Configuration.server.email._,
    },
    to      = {
      _     = "email:reset_account:to",
      name  = data.name,
      email = data.email,
    },
    subject = {
      _          = "email:reset_account:subject",
      servername = Configuration.server.name._,
      username   = data.username,
    },
    body    = {
      _          = "email:reset_account:body",
      username   = data.username,
      validation = Token.validation.new (data),
      tos        = {
        _ = "tos",
      },
    },
  }
end


function Methods.activate_user (request)
  if not Token.is_validation (token) then
    error {
      _ = "token:not-validation",
    }
  end
  token = Redis.transaction ({
    email = Configuration.redis.key.email._ % { email    = token.email    },
    data  = Configuration.redis.key.user._  % { username = token.username },
  }, function (p)
    if not p.data
    or not p.email
    or p.data.type   ~= Type.user
    or p.data.status ~= Status.inactive
    then
      error {}
    end
    p.data.status     = Status.active
    p.data.expire_at  = nil
    p.email.expire_at = nil
    return Token.authentication.new (p.data)
  end)
  return {
    token = token,
  }
end


--    > = Methods.authenticate (nil, {
--    >   username = "toto",
--    >   password = "titi",
--    > })
--    error: {...}

--    > = Methods.authenticate (nil, {
--    >   username = "username",
--    >   password = "password",
--    > })
--    {token=_.auth,...}


function Methods.suspend_user (token, request)
  if  not Token.is_authentication (token)
  and not Token.is_administration (token)
  then
    error {
      _ = "token:not-authentication",
    }
  end
  request.required = {
    username = Parameters.username,
  }
  Parameters.check (request)
  if Token.is_administration (token) then
    Redis.transaction ({
      target = Configuration.redis.key.user._ % { username = request.username },
    }, function (p)
      p.target.status   = Status.suspended
    end)
  elseif Token.is_authentication (token) then
    Redis.transaction ({
      user   = Configuration.redis.key.user._ % { username = token  .username },
      target = Configuration.redis.key.user._ % { username = request.username },
    }, function (p)
      local required_reputation = Configuration.reputation.suspend._
      if p.user.reputation < required_reputation then
        error {
          _ = "reputation:not-enough",
          owned    = p.user.reputation,
          required = required_reputation
        }
      end
      p.user.reputation = p.user.reputation - required_reputation
      p.target.status   = Status.suspended
    end)
  end
  
  if  not token.username == request.username
  and not Token.is_administration (token)
  then
    error {
      _ = "forbidden",
    }
  end

end

-- ### User Deletion

function Methods.delete_user (token, _)
  if not Token.is_authentication (token) then
    error {
      _ = "token:not-authentication",
    }
  end
  local user = Redis.transaction ({
    user = Configuration.redis.key.user._ % { username = token.username },
  }, function (p)
    p.user.status = Status.suspended
    return p.user
  end)
  for _ in pairs (user.contents) do
    -- TODO
  end
  Redis.transaction ({
    email = Configuration.redis.key.email._ % { email = user.email },
  }, function (p)
    p.email = nil
  end)
  Redis.transaction ({
    user = Configuration.redis.key.user._ % { username = token.username },
  }, function (p)
    p.user = nil
  end)
end

-- Parameters
-- ----------

function Parameters.check (request, parameters)
  parameters = parameters or {}
  local reasons  = {}
  for field in ipairs { "required", "optional" } do
    for key, parameter in pairs (parameters [field] or {}) do
      local value = request [key]
      if field == "required" and value == nil then
        reasons [#reasons+1] = {
          _   = "check:missing",
          key = key,
        }
      elseif value ~= nil then
        for _, f in ipairs (parameter) do
          local ok, reason = f {
            parameter = parameter,
            request   = request,
            key       = key,
          }
          if not ok then
            reasons [#reasons+1] = reason
            break
          end
        end
      end
    end
  end
  if #reasons ~= 0 then
    error {
      _          = "check:error",
      reasons    = reasons,
      request    = request,
      parameters = parameters,
    }
  end
end

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
    min_size = 32,
    max_size = 32,
  }
  checks = Internal.data.tos_digest.check
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
    local ok, result = loader.token.decode (value)
    if not ok then
      return nil, {
        _ = "check:token:valid",
      }
    end
    request [key] = result
    return  true
  end

  Internal.data.token.administration = {
    [Repository.refines] = {
      Configuration.data.token,
    },
  }
  checks = Internal.data.token.administration.check
  checks [#checks+1] = function (t)
    local request = t.request
    local value   = request [t.key]
    return  value.type == "administration"
        or  nil, {
              _ = "check:token:valid",
            }
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
              _ = "check:token:valid",
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
              _ = "check:token:valid",
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
        return result
      elseif result ~= Store.Error then
        error (result)
      end
    end
    error {
      _ = "redis:unavailable",
    }
  end
end

return Methods