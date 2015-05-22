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

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Email         = require "cosy.email"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Parameters    = require "cosy.parameters"
local Password      = require "cosy.password"
local Repository    = require "cosy.repository"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Value         = require "cosy.value"

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

function Methods.statistics ()
  local request  = (require "copas.http").request
  local position = request "http://www.telize.com/geoip"
  print (position)
end

-- ### Information

function Methods.information ()
  return {
    name = Configuration.server.name._,
  }
end

-- ### Terms of Service

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
  local tos = I18n {
    _      = "tos",
    locale = locale,
  }
  return {
    tos        = tos,
    tos_digest = Digest (tos),
  }
end

-- ### User Creation

function Methods.create_user (request, store, try_only)
  Parameters.check (request, {
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
  if try_only then
    return true
  end
  store.emails [request.email] = {
    username  = request.username,
  }
  store.users [request.username] = {
    type        = Methods.Type.user,
    status      = Methods.Status.active,
    username    = request.username,
    email       = request.email,
    password    = Password.hash (request.password),
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
  Parameters.check (request, {
    required = {
      username = Parameters.username,
      password = Parameters.password,
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
  local verified = Password.verify (request.password, user.password)
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

function Methods.reset_user (request, store, try_only)
  Parameters.check (request, {
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
  or user.type   ~= Methods.Type.user then
    return true
  end
  local token = Token.validation (user)
  if try_only then
    return true
  end
  local sent  = Email.send {
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
  Parameters.check (request, {
    required = {
      username = Parameters.username,
      token    = Parameters.token.authentication,
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
  Parameters.check (request, {
    required = {
      token = Parameters.token.authentication,
    },
  })
  local user = store.users [request.token.username]
  store.emails [user.email   ] = nil
  store.users  [user.username] = nil
  return true
end

Internal.redis.retry = 2

for k, f in pairs (Methods) do
  if type (f) == "function" then
    Methods [k] = function (request, try_only)
      for _ = 1, Configuration.redis.retry._ do
        local err
        local ok, result = xpcall (function ()
          local store  = Store.new ()
          local result = f (request, store, try_only)
          if not try_only then
            Store.commit (store)
          end
          return result
        end, function (e)
          err = e
          Logger.debug ("Error: " .. Value.encode (e) .. " => " .. debug.traceback ())
        end)
        if ok then
          return result or true
        elseif err ~= Store.Error then
          return nil, err
        end
      end
      return nil, {
        _ = "redis:unavailable",
      }
    end
  end
end

return Methods