local Configuration = require "cosy.configuration"
local Repository    = require "cosy.repository"
local I18n          = require "cosy.i18n"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Internal      = Configuration / "default"

Configuration.load {
  "cosy.methods",
}

local i18n   = I18n.load "cosy.parameters"
i18n._locale = Configuration.locale._

local function check (store, value, data)
  local request = {
    key = value,
  }
  for i = 1, Repository.size (data.check) do
    local ok, reason = data.check [i]._ {
      parameter = data,
      request   = request,
      key       = "key",
      store     = store,
    }
    if not ok then
      return nil, reason
    end
  end
  return true
end

-- Boolean
-- ------

Internal.data.boolean = {}
do
  local checks = Internal.data.boolean.check
  checks [1] = function (t)
    local value = t.request [t.key]
    return  type (value) == "boolean"
        or  nil, {
              _   = i18n ["check:is-table"],
            }
  end
end

Internal.data.is_private = {
  [Repository.refines] = {
    Configuration.data.boolean,
  }
}

-- Avatar
-- ------

do
  Internal.data.avatar = {
    width  = 400,
    height = 400,
  }
  local checks = Internal.data.avatar.check
  checks [1] = function (t)
    local value = t.request [t.key]
    return  type (value) == "table"
        or  nil, {
              _   = i18n ["check:is-table"],
            }
  end
  checks [2] = function (t)
    local value = t.request [t.key]
    return  type (value.source ) == "string"
       and  type (value.content) == "string"
        or  nil, {
              _   = i18n ["check:is-avatar"],
            }
  end
end

-- Position
-- --------

do
  Internal.data.position = {}
  local checks = Internal.data.position.check
  checks [1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  type (value) == "table"
        or  nil, {
              _   = i18n ["check:is-table"],
            }
  end
  checks [2] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.country
       and  value.city
        or  nil, {
              _   = i18n ["check:is-position"],
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
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  type (value) == "string"
        or  nil, {
              _   = i18n ["check:is-string"],
            }
  end
  checks [2] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local size    = t.parameter.min_size._
    return  #value >= size
        or  nil, {
              _     = i18n ["check:min-size"],
              count = size,
            }
  end
  checks [3] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local size    = t.parameter.max_size._
    return  #value <= size
        or  nil, {
              _     = i18n ["check:max-size"],
              count = size,
            }
  end
end

do
  Internal.data.string.trimmed = {
    [Repository.refines] = {
      Configuration.data.string,
    }
  }
  local checks = Internal.data.string.trimmed.check
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

do
  Internal.data.locale = {
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.locale.check
  checks [Repository.size (checks)+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%a%a$"
        or  value:find "^%a%a%-%a%a$"
        or  value:find "^%a%a%_%a%a$"
        or  nil, {
              _      = i18n ["check:locale:pattern"],
              locale = value,
            }
  end
end


-- User
-- ----
do
  Internal.data.user = {
    [Repository.refines] = {
      Configuration.data.username,
    },
  }
  local checks = Internal.data.user.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local name    = (Configuration.redis.pattern.user / value).user
    if not name then
      return nil, {
        _   = i18n ["check:user"],
        key = key,
      }
    end
    request [key] = {
      name = name
    }
    return true
  end
  checks [Repository.size (checks)+1] = function (t)
    local store   = t.store
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = store.users [name]
    request [key].user = user
    return  user
        or  nil, {
              _    = i18n ["check:user:miss"],
              name = name,
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = request [key].user
    return  user.type == Configuration.resource.type.user._
        or  nil, {
              _    = i18n ["check:user:not-user"],
              name = name,
            }
  end
end

do
  Internal.data.user.active = {
    [Repository.refines] = {
      Configuration.data.user,
    },
  }
  local checks = Internal.data.user.active.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = request [key].user
    return  user.status == Configuration.resource.status.active._
        or  nil, {
              _    = i18n ["check:user:not-active"],
              name = name,
            }
  end
end

do
  Internal.data.user.suspended = {
    [Repository.refines] = {
      Configuration.data.user,
    },
  }
  local checks = Internal.data.user.suspended.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = request [key].user
    return  user.status == Configuration.resource.status.suspended._
        or  nil, {
              _    = i18n ["check:user:not-suspended"],
              name = name,
            }
  end
end

do
  Internal.data.username = {
    min_size = 1,
    max_size = 32,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.username.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value:find "^%w[%w%-_]+$"
        or  nil, {
              _   = i18n ["check:alphanumeric"],
              key = key,
            }
  end
end

-- Project name
-- ------------
do
  Internal.data.projectname = {
    min_size = 1,
    max_size = 32,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.projectname.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value:find "^%w[%w%-_]+$"
        or  nil, {
              _   = i18n ["check:alphanumeric"],
              key = key,
            }
  end
end

-- Project
-- -------
do
  Internal.data.project = {
    [Repository.refines] = {
      Configuration.data.projectname,
    }
  }
  local checks = Internal.data.project.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local r       = Configuration.redis.pattern.project / value
    if not check (r.user   , Configuration.data.username   )
    or not check (r.project, Configuration.data.projectname)
    then
      return  nil, {
                _ = i18n ["check:project"],
              }
    end
    request [key] = {
      rawname     = value,
      username    = r.user,
      projectname = r.project,
    }
    return true
  end
  checks [Repository.size (checks)+1] = function (t)
    local store   = Store.new ()
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local project = store.projects [value.rawname]
    local Methods = require "cosy.methods"
    return  project
       and  project.type == Methods.Type.project
        or  nil, {
              _    = i18n ["check:project:miss"],
              name = value.rawname,
            }
  end
end

-- Password
-- --------
do
  Internal.data.password = {
    min_size = 1,
    max_size = 128,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
end

do
  Internal.data.password.checked = {
    [Repository.refines] = {
      Configuration.data.string.password,
    }
  }
end

-- Email
-- -----
do
  Internal.data.email = {
    max_size = 128,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.email.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local pattern = "^.*@[%w%.%%%+%-]+%.%w%w%w?%w?$"
    return  value:find (pattern)
        or  nil, {
              _     = i18n ["check:email:pattern"],
              email = value,
            }
  end
end

-- Name
-- ----
do
  Internal.data.name = {
    min_size = 1,
    max_size = 128,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
end

-- Organization
-- ------------
do
  Internal.data.organization = {
    min_size = 1,
    max_size = 128,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
end

-- Description
-- -----------
do
  Internal.data.description = {
    min_size = 1,
    max_size = 4096,
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    }
  }
end

-- Terms of Services Digest
-- ------------------------
do
  Internal.data.tos_digest = {
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    },
    min_size = 64,
    max_size = 64,
  }
  local checks = Internal.data.tos_digest.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    request [key] = value:lower ()
    return  true
  end
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local pattern = "^%x+$"
    return  value:find (pattern)
        or  nil, {
              _          = i18n ["check:tos_digest:pattern"],
              tos_digest = value,
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local Methods = require "cosy.methods"
    local tos = Methods.server.tos { locale = request.locale }
    return  tos.tos_digest == value
        or  nil, {
              _          = i18n ["check:tos_digest:incorrect"],
              tos_digest = value,
            }
  end
end

-- Token
-- -----
do
  Internal.data.token = {
    [Repository.refines] = {
      Configuration.data.string.trimmed,
    },
  }
  local checks = Internal.data.token.check
  checks [Repository.size (checks)+1] = function (t)
    local request    = t.request
    local key        = t.key
    local value      = request [key]
    local ok, result = pcall (Token.decode, value)
    if not ok then
      return nil, {
        _ = i18n ["check:token:invalid"],
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
    [Repository.refines] = {
      Configuration.data.token,
    },
  }
  local checks = Internal.data.token.administration.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.type == "administration"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local Server  = require "cosy.server"
    return  value.passphrase == Server.passphrase
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end

-- Validation token
-- ----------------
do
  Internal.data.token.validation = {
    [Repository.refines] = {
      Configuration.data.token,
    },
  }
  local checks = Internal.data.token.validation.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.type == "validation"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local store    = t.store
    local request  = t.request
    local key      = t.key
    local username = request [key].username
    local user     = store.users [username]
    request [key].user = user
    return  user
       and  user.type   == Configuration.resource.type.user._
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end

-- Authentication Token
-- --------------------
do
  Internal.data.token.authentication = {
    [Repository.refines] = {
      Configuration.data.token,
    },
  }
  local checks = Internal.data.token.authentication.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.type == "authentication"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local store    = t.store
    local request  = t.request
    local key      = t.key
    local username = request [key].username
    local user     = store.users [username]
    request [key].user = user
    return  user
       and  user.type   == Configuration.resource.type.user._
       and  user.status == Configuration.resource.status.active._
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end
