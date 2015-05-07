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

-- Dependencies
-- ------------
--
-- This module depends on the following modules:
local loader        = require "cosy.loader"

local Repository    = loader.repository
local Configuration = loader.configuration
local Internal      = Repository.of (Configuration) .internal

Internal.redis.key = {
  users  = "user:%{key}",
  emails = "email:%{key}",
  tokens = "token:%{key}",
}

Methods.Status = setmetatable ({
  inactive  = "inactive",
  active    = "active",
  suspended = "suspended",
}, {
  __index = assert,
})

Methods.Type = setmetatable ({
  user = "user",
}, {
  __index = assert,
})

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
  loader.parameters.check (request, {
    optional = {
      token  = loader.parameters.token,
      locale = loader.parameters.locale,
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
  loader.parameters.check (request, {
    required = {
      username   = loader.parameters.username,
      password   = loader.parameters.password,
      email      = loader.parameters.email,
      tos_digest = loader.parameters.tos_digest,
      locale     = loader.parameters.locale,
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
    type        = Methods.Type.user,
    status      = Methods.Status.active,
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
  loader.parameters.check (request, {
    required = {
      username = loader.parameters.username,
      password = loader.parameters.password,
    },
  })
  local user = store.users [request.username]
  if not user
  or user.type   ~= Methods.Type.user
  or user.status ~= Methods.Status.active then
    error {
      _ = "authenticate:failure",
    }
  end
  local verified = loader.password.verify (request.password, user.password)
  if not verified then
    error {
      _ = "authenticate:failure",
    }
  end
  if type (verified) == "string" then
    user.password = verified
  end
  return Token.authentication (user)
end

-- ### Reset password

function Methods.reset_user (request, store)
  loader.parameters.check (request, {
    required = {
      email = loader.parameters.email,
    },
  })
  local email = store.emails [request.email]
  if not email then
    return true
  end
  local user = store.users [email.username]
  if not user
  or user.type   ~= Methods.Type.user then
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
    user.status     = Methods.Status.suspended
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
  loader.parameters.check (request, {
    required = {
      username = loader.parameters.username,
      token    = loader.parameters.token.authentication,
    },
  })
  local target = store.users [request.username]
  if target.type ~= Methods.Type.user then
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
  target.status   = Methods.Status.suspended
  return true
end

-- ### User Deletion

function Methods.delete_user (request, store)
  loader.parameters.check (request, {
    required = {
      token = loader.parameters.token.authentication,
    },
  })
  local user = store.users [request.token.username]
  store.emails [user.email   ] = nil
  store.users  [user.username] = nil
  return true
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
      local err
      local ok, result = xpcall (function ()
        local store  = loader.store.new ()
        local result = f (request, store)
        loader.store.commit (store)
        return result
      end, function (e)
        err = e
        loader.logger.debug ("Error: " .. loader.value.encode (e) .. " => " .. debug.traceback ())
      end)
      if ok then
        return result or true
      elseif err ~= loader.store.Error then
        return nil, err
      end
    end
    return nil, {
      _ = "redis:unavailable",
    }
  end
end

return Methods