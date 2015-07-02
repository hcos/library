local Methods  = {}

local Access        = require "cosy.access"
local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Email         = require "cosy.email"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Parameters    = require "cosy.parameters"
local Password      = require "cosy.password"
local Redis         = require "cosy.redis"
local Store         = require "cosy.store"
local Time          = require "cosy.time"
local Token         = require "cosy.token"
local Coromake      = require "coroutine.make"

Configuration.load {
  "cosy.methods",
  "cosy.parameters",
}

local i18n   = I18n.load "cosy.methods"
i18n._locale = Configuration.locale

-- Server
-- ------

Methods.server = {}

function Methods.server.list_methods (request, store)
  Parameters.check (store, request, {
    optional = {
      locale = Parameters.locale,
    },
  })
  local locale = Configuration.locale
  if request.locale then
    locale = request.locale or locale
  end
  local result = {}
  local function f (current, prefix)
    for k, v in pairs (current) do
      local ok, err = pcall (function ()
        if type (v) == "function" then
          local name = (prefix or "") .. k:gsub ("_", "-")
          result [name] = i18n [name] % { locale = locale }
        elseif type (v) == "table" then
          f (v, (prefix or "") .. k:gsub ("_", "-") .. ":")
        end
      end)
      if not ok then
        Logger.warning {
          _      = i18n ["translation:failure"],
          reason = err,
        }
        local name = (prefix or "") .. k:gsub ("_", "-")
        result [name] = name
      end
    end
  end
  f (Methods, nil)
  return result
end

function Methods.server.stop (request, store)
  Parameters.check (store, request, {
    required = {
      administration = Parameters.token.administration,
    },
  })
  local Server = require "cosy.server"
  return Server.stop ()
end

function Methods.server.information (request, store)
  Parameters.check (store, request, {})
  return {
    name    = Configuration.server.name,
    captcha = Configuration.recaptcha.public_key,
  }
end

function Methods.server.tos (request, store)
  Parameters.check (store, request, {
    optional = {
      authentication = Parameters.token.authentication,
      locale         = Parameters.locale,
    },
  })
  local locale = Configuration.locale
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

function Methods.server.filter (request, store)
  Parameters.check (store, request, {
    required = {
      iterator       = Parameters.iterator,
    },
    optional = {
      authentication = Parameters.token.authentication,
    }
  })
  if request.authentication then
    local user = request.authentication.user
    if user.reputation < Configuration.reputation.filter then
      error {
        _        = i18n ["server:filter:not-enough"],
        owned    = user.reputation,
        required = Configuration.reputation.filter,
      }
    end
  end
  local access    = Access.new (request.authentication, store)
  local coroutine = Coromake ()
  local co        = coroutine.create (request.iterator)
  local results   = {}
  while coroutine.status (co) ~= "dead" do
    local ok, result = coroutine.resume (co, coroutine.yield, access)
    if not ok then
      error {
        _      = i18n ["server:filter:error"],
        reason = result,
      }
    end
    if result ~= nil then
      results [#results+1] = result
    end
  end
  return results
end

-- User
-- ----

Methods.user = {}

function Methods.user.create (request, store, try_only)
  Parameters.check (store, request, {
    required = {
      username   = Parameters.user.name,
      password   = Parameters.password.checked,
      email      = Parameters.email,
      tos_digest = Parameters.tos.digest,
      locale     = Parameters.locale,
      ip         = Parameters.ip,
      captcha    = Parameters.captcha,
    },
  })
  if store.email [request.email] then
    error {
      _     = i18n ["email:exist"],
      email = request.email,
    }
  end
  if store.user [request.username] then
    error {
      _        = i18n ["username:exist"],
      username = request.username,
    }
  end
  do
    local Http = require "copas.http"
    local Json = require "cosy.json"
    local url  = "https://www.google.com/recaptcha/api/siteverify"
    local body = "secret="    .. Configuration.recaptcha.private_key
              .. "&response=" .. request.captcha
              .. "&remoteip=" .. request.ip
    local response, status = Http.request (url, body)
    assert (status == 200)
    response = Json.decode (response)
    assert (response)
    if not response.success then
      error {
        _        = i18n ["captcha:failure"],
        username = request.username,
      }
    end
  end
  store.email [request.email] = {
    username  = request.username,
  }
  if request.locale == nil then
    request.locale = Configuration.locale
  end
  local user = {
    checked     = false,
    email       = request.email,
    lastseen    = Time (),
    locale      = request.locale,
    password    = Password.hash (request.password),
    tos_digest  = request.tos_digest,
    reputation  = Configuration.reputation.initial,
    status      = "active",
    type        = "user",
    username    = request.username,
  }
  store.user [request.username] = user
  if try_only then
    return true
  end
  Email.send {
    locale  = user.locale,
    from    = {
      _     = i18n ["user:create:from"],
      name  = Configuration.server.name ,
      email = Configuration.server.email,
    },
    to      = {
      _     = i18n ["user:create:to"],
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = i18n ["user:create:subject"],
      servername = Configuration.server.name,
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

function Methods.user.send_validation (request, store, try_only)
  Parameters.check (store, request, {
    required = {
      authentication = Parameters.token.authentication,
    },
  })
  local user = request.authentication.user
  if try_only then
    return true
  end
  Email.send {
    locale  = user.locale,
    from    = {
      _     = i18n ["user:update:from"],
      name  = Configuration.server.name ,
      email = Configuration.server.email,
    },
    to      = {
      _     = i18n ["user:update:to"],
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = i18n ["user:update:subject"],
      servername = Configuration.server.name,
      username   = user.username,
    },
    body    = {
      _          = i18n ["user:update:body"],
      username   = user.username,
      token      = Token.validation (user),
    },
  }
end

function Methods.user.validate (request, store)
  Parameters.check (store, request, {
    required = {
      validation = Parameters.token.validation,
    },
  })
  local user = request.validation.user
  user.checked = true
end

function Methods.user.authenticate (request, store)
  local ok, err = pcall (function ()
    Parameters.check (store, request, {
      required = {
        user     = Parameters.user.active,
        password = Parameters.password,
      },
    })
  end)
  if not ok then
    if request.__DESCRIBE then
      error (err)
    else
      error {
        _ = i18n ["user:authenticate:failure"],
      }
    end
  end
  local user     = request.user
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

function Methods.user.is_authentified (request, store)
  Parameters.check (store, request, {
    required = {
      authentication = Parameters.token.authentication,
    },
  })
  return {
    username = request.authentication.username,
  }
end

function Methods.user.update (request, store, try_only)
  Parameters.check (store, request, {
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
      username     = Parameters.user.name,
    },
  })
  local user = request.authentication.user
  if request.username then
    if store.user [request.username] then
      error {
        _        = i18n ["username:exist"],
        username = request.username,
      }
    end
    local filter = Configuration.redis.pattern.project % {
      user    = user.username,
      project = "*",
    }
    for name, project in Store.filter (store.project, filter) do
      local projectname = (Configuration.redis.pattern.project / name).project
      project.username = request.username
      local old = Configuration.redis.pattern.project % {
        user    = user.username,
        project = projectname,
      }
      local new = Configuration.redis.pattern.project % {
        user    = request.username,
        project = projectname,
      }
      store.project [old] = nil
      store.project [new] = project
    end
    store.user [user.username   ] = nil
    store.user [request.username] = user
    user.username = request.username
    store.email [user.email].username = request.username
  end
  if request.email then
    if store.email [request.email] then
      error {
        _     = i18n ["email:exist"],
        email = request.email,
      }
    end
    store.email [user.email   ] = nil
    store.email [request.email] = {
      username  = user.username,
    }
    user.email   = request.email
    user.checked = false
    Methods.user.send_validation ({
      authentication = Token.authentication (user),
      try_only       = try_only,
    }, store)
  end
  if request.password then
    user.password = Password.hash (request.password)
  end
  if request.position then
    user.position = {
      country        = request.position.country,
      city           = request.position.city,
      latitude       = request.position.latitude,
      longitude      = request.position.longitude,
      continent_code = request.position.continent_code,
      country_code   = request.position.country_code,
      timezone       = request.position.timezone,
    }
  end
  if request.avatar then
    local redis   = Redis ()
    local content = redis:get (request.avatar)
    redis:del (request.avatar)
    local filename = os.tmpname ()
    local file = io.open (filename, "w")
    file:write (content)
    file:close ()
    os.execute ([[
      convert {{{file}}} -resize {{{width}}}x{{{height}}} png:{{{file}}}
    ]] % {
      file   = filename,
      height = Configuration.data.avatar.height,
      width  = Configuration.data.avatar.width ,
    })
    file = io.open (filename, "r")
    user.avatar = file:read "*all"
    file:close ()
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

function Methods.user.information (request, store)
  Parameters.check (store, request, {
    required = {
      user = Parameters.user,
    },
  })
  local user = request.user
  return {
    avatar       = user.avatar,
    homepage     = user.homepage,
    name         = user.name,
    organization = user.organization,
    position     = user.position,
    username     = user.username,
  }
end

function Methods.user.recover (request, store, try_only)
  Parameters.check (store, request, {
    required = {
      validation = Parameters.token.validation,
      password   = Parameters.password.checked,
    },
  })
  local user = request.validation.user
  Methods.user.update ({
    authentication = Token.authentication (user),
    password       = request.password,
    try_only       = try_only,
  }, store)
  return Methods.user.authenticate ({
    username = user.username,
    password = request.password,
  }, store)
end

function Methods.user.reset (request, store, try_only)
  Parameters.check (store, request, {
    required = {
      email = Parameters.email,
    },
  })
  local email = store.email [request.email]
  if not email then
    return
  end
  local user = store.user [email.username]
  if not user
  or user.type ~= "user" then
    return
  end
  user.password = ""
  if try_only then
    return
  end
  Email.send {
    locale  = user.locale,
    from    = {
      _     = i18n ["user:reset:from"],
      name  = Configuration.server.name ,
      email = Configuration.server.email,
    },
    to      = {
      _     = i18n ["user:reset:to"],
      name  = user.username,
      email = user.email,
    },
    subject = {
      _          = i18n ["user:reset:subject"],
      servername = Configuration.server.name,
      username   = user.username,
    },
    body    = {
      _          = i18n ["user:reset:body"],
      username   = user.username,
      validation = Token.validation (user),
    },
  }
end

function Methods.user.suspend (request, store)
  Parameters.check (store, request, {
    required = {
      authentication = Parameters.token.authentication,
      user           = Parameters.user.active,
    },
  })
  local target = request.user
  if request.user.username == request.authentication.username then
    error {
      _ = i18n ["user:suspend:self"],
    }
  end
  local user       = request.authentication.user
  local reputation = Configuration.reputation.suspend
  if user.reputation < reputation then
    error {
      _        = i18n ["user:suspend:not-enough"],
      owned    = user.reputation,
      required = reputation
    }
  end
  user.reputation = user.reputation - reputation
  target.status   = "suspended"
end

function Methods.user.release (request, store)
  Parameters.check (store, request, {
    required = {
      user           = Parameters.user.suspended,
      authentication = Parameters.token.authentication,
    },
  })
  local target = request.user
  if request.user.username == request.authentication.username then
    error {
      _ = i18n ["user:release:self"],
    }
  end
  local user       = request.authentication.user
  local reputation = Configuration.reputation.release
  if user.reputation < reputation then
    error {
      _        = i18n ["user:suspend:not-enough"],
      owned    = user.reputation,
      required = reputation
    }
  end
  user.reputation = user.reputation - reputation
  target.status   = "active"
end

function Methods.user.delete (request, store)
  Parameters.check (store, request, {
    required = {
      authentication = Parameters.token.authentication,
    },
  })
  local user = request.authentication.user
  store.email [user.email   ] = nil
  store.user  [user.username] = nil
  local filter = Configuration.resource.project.pattern % {
    user    = user.username,
    project = "*",
  }
  for name in Store.filter (store.project, filter) do
    store.project [name] = nil
  end
end

-- Project
-- -------

Methods.project = {}

function Methods.project.create (request, store)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.authentication,
      projectname    = Parameters.projectname,
    },
    optional = {
      is_private = Parameters.is_private,
    },
  })
  local user = store.user [request.authentication.username]
  local name = Configuration.resource.project.pattern % {
    user    = user.username,
    project = request.projectname,
  }
  local project = store.project [name]
  if project then
    error {
      _    = i18n ["project:exist"],
      name = name,
    }
  end
  store.project [name] = {
    permissions = {},
    projectname = request.projectname,
    type        = "project",
    username    = user.username,
  }
end

function Methods.project.delete (request, store)
  Parameters.check (request, {
    required = {
      authentication = Parameters.token.authentication,
      project        = Parameters.project,
    },
  })
  local project = store.project [request.project.rawname]
  if not project then
    error {
      _    = i18n ["project:miss"],
      name = request.project.rawname,
    }
  end
  local user    = store.user [request.authentication.username]
  if project.username ~= user.username then
    error {
      _    = i18n ["project:forbidden"],
      name = project.projectname,
    }
  end
  store.project [request.project.rawname] = nil
end

return Methods
