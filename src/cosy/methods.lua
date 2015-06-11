local Methods  = {}

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Email         = require "cosy.email"
local I18n          = require "cosy.i18n"
local Parameters    = require "cosy.parameters"
local Password      = require "cosy.password"
local Time          = require "cosy.time"
local Token         = require "cosy.token"

Configuration.load "cosy.methods"
Configuration.load "cosy.parameters"

local i18n   = I18n.load "cosy.methods"
i18n._locale = Configuration.locale._

Methods.Status = setmetatable ({
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

Methods.server = {}


function Methods.server.list_methods (request)
  Parameters.check (request, {
    optional = {
      locale = Parameters.locale,
    },
  })
  local locale = Configuration.locale.default._
  if request.locale then
    locale = request.locale or locale
  end
  local result = {}
  local function f (current, prefix)
    for k, v in pairs (current) do
      if type (v) == "function" then
        local name = (prefix or "") .. k:gsub ("_", "-")
        result [name] = i18n [name] % { locale = locale }
      elseif type (v) == "table" then
        f (v, (prefix or "") .. k:gsub ("_", "-") .. ":")
      end
    end
  end
  f (Methods, nil)
  return result
end

function Methods.server.stop (request)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.administration,
    },
  })
  local Server = require "cosy.server"
  return Server.stop ()
end

-- ### Information

function Methods.server.information (request)
  Parameters.check (request, {})
  return {
    name = Configuration.server.name._,
  }
end

-- ### Terms of Service

function Methods.server.tos (request)
  Parameters.check (request, {
    optional = {
      authentication = Parameters.token.authentication,
      locale         = Parameters.locale,
    },
  })
  local locale = Configuration.locale.default._
  if request.locale then
    locale = request.locale or locale
  end
  if request.authentication then
    locale = request.authentication.locale or locale
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
      password   = Parameters.password.checked,
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
    checked     = false,
    password    = Password.hash (request.password),
    locale      = request.locale,
    tos_digest  = request.tos_digest,
    reputation  = Configuration.reputation.at_creation._,
    lastseen    = Time (),
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
      token      = Token.validation (user),
    },
  }
  return {
    authentication = Token.authentication (user),
  }
end

-- ### Send Validation email

function Methods.user.send_validation (request, store, try_only)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.authentication,
    },
  })
  if try_only then
    return true
  end
  local user = store.users [request.authentication.username]
  Email.send {
    locale  = user.locale,
    from    = {
      _     = i18n ["user:update:from"],
      name  = Configuration.server.name._,
      email = Configuration.server.email._,
    },
    to      = {
      _     = i18n ["user:update:to"],
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = i18n ["user:update:subject"],
      servername = Configuration.server.name._,
      username   = user.username,
    },
    body    = {
      _          = i18n ["user:update:body"],
      username   = user.username,
      token      = Token.validation (user),
    },
  }
end

-- ### Validate email

function Methods.user.validate (request, store, try_only)
  Parameters.check (request, {
    required = {
      validation = Parameters.token.validation,
    },
  })
  if try_only then
    return true
  end
  local user = store.users [request.authentication.username]
  user.checked = true
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
  user.lastseen = Time ()
  return {
    authentication = Token.authentication (user),
  }
end

-- ### Is authentified?

function Methods.user.is_authentified (request)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.authentication,
    },
  })
  return true
end

-- ### Update

function Methods.user.update (request, store)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.authentication,
    },
    optional = {
      avatar       = Parameters.avatar,
      email        = Parameters.email,
      homepage     = Parameters.homepage,
      locale       = Parameters.locale,
      name         = Parameters.name,
      organization = Parameters.organization,
      password     = Parameters.password.checked,
      position     = Parameters.position,
      username     = Parameters.username,
    },
  })
  local user = store.users [request.authentication.username]
  if request.username then
    if store.users [request.username] then
      error {
        _        = i18n ["username:exist"],
        username = request.username,
      }
    end
    store.users [user.username   ] = nil
    store.users [request.username] = user
    user.username = request.username
    store.emails [user.email].username = request.username
  end
  if request.email then
    if store.emails [request.email] then
      error {
        _     = i18n ["email:exist"],
        email = request.email,
      }
    end
    store.emails [user.email   ] = nil
    store.emails [request.email] = {
      username  = user.username,
    }
    user.email   = request.email
    user.checked = false
    Methods.user.send_validation {
      authentication = request.authentication,
    }
  end
  if request.password then
    user.password = Password.hash (request.password)
  end
  if request.position then
    user.position = {
      country = request.position.country,
      city    = request.position.city,
    }
  end
  if request.avatar then
    local filename = os.tmpname ()
    local file = io.open (filename, "w")
    file:write (request.avatar.content)
    file:close ()
    os.execute ([[
      convert {{{file}}} -resize {{{width}}}x{{{height}}} png:{{{file}}}
    ]] % {
      file   = filename,
      height = Configuration.data.avatar.height._,
      width  = Configuration.data.avatar.width._,
    })
    file = io.open (filename, "r")
    request.avatar.content = file:read "*all"
    file:close ()
    user.avatar = request.avatar
  end
  for _, key in ipairs { "name", "organization", "locale" } do
    if request [key] then
      user [key] = request [key]
    end
  end
  return {
    avatar         = user.avatar,
    checked        = user.checked,
    email          = user.email,
    homepage       = user.homepage,
    lastseen       = user.lastseen,
    locale         = user.locale,
    name           = user.name,
    organization   = user.organization,
    position       = user.position,
    username       = user.username,
    authentication = Token.authentication (user)
  }
end

-- ### Update

function Methods.user.information (request, store)
  Parameters.check (request, {
    required = {
      username = Parameters.username,
    },
  })
  local user = store.users [request.username]
  if not user
  or user.type   ~= Methods.Type.user then
    error {
      _        = i18n ["username:miss"],
      username = request.username,
    }
  end
  return {
    avatar       = user.avatar,
    homepage     = user.homepage,
    name         = user.name,
    organization = user.organization,
    position     = user.position,
    username     = user.username,
  }
end

-- ### Recover

function Methods.user.recover (request, store, try_only)
  Parameters.check (request, {
    required = {
      validation = Parameters.token.validation,
      password   = Parameters.password.checked,
    },
  })
  local user = store.users [request.validation.username]
  if try_only then
    return
  end
  Methods.user.update {
    authentication = Token.authentication (user),
    password       = request.password,
  }
  return Methods.user.authenticate {
    username = user.username,
    password = request.password,
  }
end

-- ### Reset

function Methods.user.reset (request, store, try_only)
  Parameters.check (request, {
    required = {
      email = Parameters.email,
    },
  })
  local email = store.emails [request.email]
  if not email then
    return
  end
  local user = store.users [email.username]
  if not user
  or user.type ~= Methods.Type.user then
    return
  end
  if try_only then
    return
  end
  user.password = ""
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
      validation = Token.validation (user),
    },
  }
end

-- ### Suspend User

function Methods.user.suspend (request, store)
  Parameters.check (request, {
    required = {
      username       = Parameters.username,
      authentication = Parameters.token.authentication,
    },
  })
  local target = store.users [request.username]
  if target.type ~= Methods.Type.user then
    error {
      _        = i18n ["user:suspend:not-user"],
      username = request.username,
    }
  end
  if request.username == request.authentication.username then
    error {
      _ = i18n ["user:suspend:self"],
    }
  end
  local user       = store.users [request.authentication.username]
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
end

-- # Release user

function Methods.user.release (request, store)
  Parameters.check (request, {
    required = {
      username       = Parameters.username,
      authentication = Parameters.token.authentication,
    },
  })
  local target = store.users [request.username]
  if target.type ~= Methods.Type.user then
    error {
      _        = i18n ["user:release:not-user"],
      username = request.username,
    }
  end
  if target.status ~= Methods.Status.suspended then
    error {
      _        = i18n ["user:release:not-suspended"],
      username = request.username,
    }
  end
  if request.username == request.authentication.username then
    error {
      _ = i18n ["user:release:self"],
    }
  end
  local user       = store.users [request.authentication.username]
  local reputation = Configuration.reputation.release._
  if user.reputation < reputation then
    error {
      _        = i18n ["user:suspend:not-enough"],
      owned    = user.reputation,
      required = reputation
    }
  end
  user.reputation = user.reputation - reputation
  target.status   = Methods.Status.active
end

-- ### User Deletion

function Methods.user.delete (request, store)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.authentication,
    },
  })
  local user = store.users [request.authentication.username]
  store.emails [user.email   ] = nil
  store.users  [user.username] = nil
end

return Methods
