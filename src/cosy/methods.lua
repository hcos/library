local Methods  = {}

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Email         = require "cosy.email"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Parameters    = require "cosy.parameters"
local Password      = require "cosy.password"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Value         = require "cosy.value"

local i18n   = I18n.load (require "cosy.methods-i18n")
i18n._locale = Configuration.locale._

local Internal = Configuration / "default"
Internal.redis.retry = 5
Internal.redis.key = {
  users  = "user:{{{key}}}",
  emails = "email:{{{key}}}",
  tokens = "token:{{{key}}}",
}
Internal.expiration = {
  account        = 24 * 3600, -- 1 day
  validation     =  1 * 3600, -- 1 hour
  authentication =  1 * 3600, -- 1 hour
  administration =  99 * 365 * 24 * 3600, -- 99 years
}
Internal.reputation = {
  at_creation = 10,
  suspend     = 50,
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

function Methods.stop (request)
  Parameters.check (request, {
    required = {
      token  = Parameters.token.administration,
    },
  })
  local Server = require "cosy.server"
  return Server.stop ()
end

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
  local tos = i18n ["terms-of-service"] % {
    locale = locale,
  }
  return {
    tos        = tos,
    tos_digest = Digest (tos),
  }
end

Methods.user = {}

-- ### User Creation

function Methods.user.create (request, store, try_only)
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
      _     = i18n ["email:exist"],
      email = request.email,
    }
  end
  if store.users [request.username] then
    error {
      _        = i18n ["username:exist"],
      username = request.username,
    }
  end
  if try_only then
    return true
  end
  store.emails [request.email] = {
    username  = request.username,
  }
  local user = {
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
  store.users [request.username] = user
  Email.send {
    locale  = user.locale,
    from    = {
      _     = i18n ["user:create:from"],
      name  = Configuration.server.name._,
      email = Configuration.server.email._,
    },
    to      = {
      _     = i18n ["user:create:to"],
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = i18n ["user:create:subject"],
      servername = Configuration.server.name._,
      username   = user.username,
    },
    body    = {
      _          = i18n ["user:create:body"],
      username   = user.username,
    },
  }
  return {
    token = Token.authentication (store.users [request.username]),
  }
end

-- ### Authentication

function Methods.user.authenticate (request, store)
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
      _ = i18n ["user:authenticate:failure"],
    }
  end
  local verified = Password.verify (request.password, user.password)
  if not verified then
    error {
      _ = i18n ["user:authenticate:failure"],
    }
  end
  if type (verified) == "string" then
    user.password = verified
  end
  return {
    token = Token.authentication (user),
  }
end

function Methods.user.is_authentified (request)
  Parameters.check (request, {
    required = {
      token = Parameters.token.authentication,
    },
  })
  return true
end

-- ### Reset password

function Methods.user.reset (request, store, try_only)
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
  Email.send {
    locale  = user.locale,
    from    = {
      _     = i18n ["user:reset:from"],
      name  = Configuration.server.name._,
      email = Configuration.server.email._,
    },
    to      = {
      _     = i18n ["user:reset:to"],
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = i18n ["user:reset:subject"],
      servername = Configuration.server.name._,
      username   = user.username,
    },
    body    = {
      _          = i18n ["user:reset:body"],
      username   = user.username,
      validation = token,
    },
  }
  user.status     = Methods.Status.suspended
  user.validation = token
  return true
end

-- ### Suspend User

function Methods.user.suspend (request, store)
  Parameters.check (request, {
    required = {
      username = Parameters.username,
      token    = Parameters.token.authentication,
    },
  })
  local target = store.users [request.username]
  if target.type ~= Methods.Type.user then
    error {
      _        = i18n ["user:suspend:not-user"],
      username = request.username,
    }
  end
  if request.username == request.token.username then
    error {
      _ = i18n ["user:suspend:self"],
    }
  end
  local user       = store.users [request.token.username]
  local reputation = Configuration.reputation.suspend._
  if user.reputation < reputation then
    error {
      _        = i18n ["user:suspend:not-enough"],
      owned    = user.reputation,
      required = reputation
    }
  end
  user.reputation = user.reputation - reputation
  target.status   = Methods.Status.suspended
  return true
end

-- ### User Deletion

function Methods.user.delete (request, store)
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

local function wrap (t)
  for key, value in pairs (t) do
    if type (value) == "table" then
      wrap (value)
    elseif type (value) == "function" then
      t [key] = function (request, try_only)
        for _ = 1, Configuration.redis.retry._ do
          local err
          local ok, result = xpcall (function ()
            local store  = Store.new ()
            local result = value (request, store, try_only)
            if not try_only then
              Store.commit (store)
            end
            return result
          end, function (e)
            err = e
            Logger.debug ("Error: " .. Value.expression (e) .. " => " .. debug.traceback ())
          end)
          if ok then
            return result or true
          elseif err ~= Store.Error then
            return nil, err
          end
        end
        return nil, {
          _ = i18n ["redis:unreachable"],
        }
      end
    end
  end
  return t
end

return wrap (Methods)
