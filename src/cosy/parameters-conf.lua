local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Internal      = Configuration / "default"
local Layer         = require "layeredata"

Configuration.load {
  "cosy.methods",
}

local i18n   = I18n.load "cosy.parameters"
i18n._locale = Configuration.locale [nil]

local function check (store, value, data)
  local request = {
    key = value,
  }
  for i = 1, Layer.size (data.check) do
    local ok, reason = data.check [i] [nil] {
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
  __refines__ = {
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
       and  value.latitude
       and  value.longiture
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
    local size    = t.parameter.min_size [nil]
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
    local size    = t.parameter.max_size [nil]
    return  #value <= size
        or  nil, {
              _     = i18n ["check:max-size"],
              count = size,
            }
  end
end

do
  Internal.data.string.trimmed = {
    __refines__ = {
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
  checks [3] = Internal.data.string.check [2] [nil]
  checks [4] = Internal.data.string.check [3] [nil]
end

do
  Internal.data.locale = {
    __refines__ = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.locale.check
  checks [Layer.size (checks)+1] = function (t)
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
  Internal.data.username = {
    min_size = 1,
    max_size = 32,
    __refines__ = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.username.check
  checks [Layer.size (checks)+1] = function (t)
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

do
  Internal.data.user = {
    __refines__ = {
      Configuration.data.username,
    },
  }
  local checks = Internal.data.user.check
  checks [Layer.size (checks)+1] = function (t)
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
  checks [Layer.size (checks)+1] = function (t)
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
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = request [key].user
    return  user.type == Configuration.resource.type.user [nil]
        or  nil, {
              _    = i18n ["check:user:not-user"],
              name = name,
            }
  end
end

do
  Internal.data.user.active = {
    __refines__ = {
      Configuration.data.user,
    },
  }
  local checks = Internal.data.user.active.check
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = request [key].user
    return  user.status == Configuration.resource.status.active [nil]
        or  nil, {
              _    = i18n ["check:user:not-active"],
              name = name,
            }
  end
end

do
  Internal.data.user.suspended = {
    __refines__ = {
      Configuration.data.user,
    },
  }
  local checks = Internal.data.user.suspended.check
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local name    = request [key].name
    local user    = request [key].user
    return  user.status == Configuration.resource.status.suspended [nil]
        or  nil, {
              _    = i18n ["check:user:not-suspended"],
              name = name,
            }
  end
end

-- Project name
-- ------------
do
  Internal.data.projectname = {
    min_size = 1,
    max_size = 32,
    __refines__ = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.projectname.check
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
      Configuration.data.projectname,
    }
  }
  local checks = Internal.data.project.check
  checks [Layer.size (checks)+1] = function (t)
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
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
      Configuration.data.string.trimmed,
    }
  }
end

do
  Internal.data.password.checked = {
    __refines__ = {
      Configuration.data.string.password,
    }
  }
end

-- Email
-- -----
do
  Internal.data.email = {
    max_size = 128,
    __refines__ = {
      Configuration.data.string.trimmed,
    }
  }
  local checks = Internal.data.email.check
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
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
    __refines__ = {
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
    __refines__ = {
      Configuration.data.string.trimmed,
    }
  }
end

-- Terms of Services Digest
-- ------------------------
do
  Internal.data.tos_digest = {
    __refines__ = {
      Configuration.data.string.trimmed,
    },
    min_size = 64,
    max_size = 64,
  }
  local checks = Internal.data.tos_digest.check
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    request [key] = value:lower ()
    return  true
  end
  checks [Layer.size (checks)+1] = function (t)
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
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
      Configuration.data.string.trimmed,
    },
  }
  local checks = Internal.data.token.check
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
      Configuration.data.token,
    },
  }
  local checks = Internal.data.token.administration.check
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.type == "administration"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
      Configuration.data.token,
    },
  }
  local checks = Internal.data.token.validation.check
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.type == "validation"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Layer.size (checks)+1] = function (t)
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
    __refines__ = {
      Configuration.data.token,
    },
  }
  local checks = Internal.data.token.authentication.check
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value.type == "authentication"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Layer.size (checks)+1] = function (t)
    local store    = t.store
    local request  = t.request
    local key      = t.key
    local username = request [key].username
    local user     = store.users [username]
    request [key].user = user
    return  user
       and  user.type   == Configuration.resource.type.user     [nil]
       and  user.status == Configuration.resource.status.active [nil]
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end
