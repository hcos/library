local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Default       = require "cosy.configuration-layers".default
local Layer         = require "layeredata"
local this          = Layer.reference "configuration"

Configuration.load "cosy.methods"

local i18n   = I18n.load "cosy.parameters"
i18n._locale = Configuration.locale

do
  Default.data = {
    checks = {}
  }
end

do
  Default.data.boolean = {
    __refines__ = {
      this.data,
    }
  }
  local checks = Default.data.boolean.checks
  checks [1] = function (t)
    local value = t.request [t.key]
    return  type (value) == "boolean"
        or  nil, {
              _ = i18n ["check:is-boolean"],
            }
  end
end

do
  Default.data.is_private = {
    __refines__ = {
      this.data.boolean,
    }
  }
end

do
  Default.data.position = {
    __refines__ = {
      this.data,
    },
  }
  local checks = Default.data.position.checks
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
       and  value.longitude
        or  nil, {
              _   = i18n ["check:is-position"],
            }
  end
end

-- String
-- ------

do
  Default.data.string = {
    __refines__ = {
      this.data,
    },
    min_size = 0,
    max_size = math.huge,
  }
  local checks = Default.data.string.checks
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
    local size    = t.parameter.min_size
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
    local size    = t.parameter.max_size
    return  #value <= size
        or  nil, {
              _     = i18n ["check:max-size"],
              count = size,
            }
  end
end

-- Avatar
-- ------

do
  Default.data.avatar = {
    width  = 400,
    height = 400,
    __refines__ = {
      this.data.string,
    },
  }
end

do
  Default.data.string.trimmed = {
    __refines__ = {
      this.data.string,
    }
  }
  local checks = Default.data.string.trimmed.checks
  checks [2] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    request [key] = value:trim ()
    return true
  end
  checks [3] = Default.data.string.checks [2]
  checks [4] = Default.data.string.checks [3]
end

do
  Default.data.locale = {
    __refines__ = {
      this.data.string.trimmed,
    }
  }
  local checks = Default.data.locale.checks
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    return  value:find "^%a%a$"
        or  value:find "^%a%a%-%a%a$"
        or  value:find "^%a%a%_%a%a$"
        or  nil, {
              _      = i18n ["check:locale:pattern"],
              locale = value,
            }
  end
end

-- Function
-- --------

do
  Default.data.iterator = {
    __refines__ = {
      this.data.string,
    },
  }
  local checks = Default.data.iterator.checks
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    -- http://lua-users.org/wiki/SandBoxes
    local environment = {
      assert   = assert,
      error    = error,
      pairs    = pairs,
      ipairs   = ipairs,
      next     = next,
      pcall    = pcall,
      select   = select,
      tonumber = tonumber,
      tostring = tostring,
      type     = type,
      unpack   = unpack,
      xpcall   = xpcall,
      string   = string,
      table    = table,
      math     = math,
    }
    if _VERSION == "Lua 5.1" then
      if value:byte (1) == 27 then
        return nil, {
          _      = i18n ["check:iterator:bytecode"],
        }
      end
      local f, err = loadstring (value)
      if not f then
        return nil, {
          _      = i18n ["check:iterator:function"],
          reason = err,
        }
      end
      setfenv (f, environment)
      request [key] = f
    else
      local f, err = load (value, nil, 't', environment)
      if not f then
        return nil, {
          _      = i18n ["check:iterator:function"],
          reason = err,
        }
      end
      request [key] = f
    end
    local _, result = pcall (request [key])
    request [key] = result
    return  type (request [key]) == "function"
        or  nil, {
              _      = i18n ["check:iterator:function"],
              reason = result,
            }
  end
end

-- User
-- ----
do
  Default.data.user = {
    __refines__ = {
      this.data.user.name,
    },
    name = {
      min_size = 1,
      max_size = 32,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  }
  local checks = Default.data.user.name.checks
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
  local checks = Default.data.user.checks
  checks [Layer.size (checks)+1] = function (t)
    local store   = t.store
    local request = t.request
    local key     = t.key
    local name    = request [key]
    return  Store.exists (store.user, name)
        or  nil, {
              _    = i18n ["check:user:miss"],
              name = name,
            }
  end
  checks [Layer.size (checks)+1] = function (t)
    local store   = t.store
    local request = t.request
    local key     = t.key
    local name    = request [key]
    local user    = store.user [name]
    request [key] = user
    return  user.type == "user"
        or  nil, {
              _    = i18n ["check:user:not-user"],
              name = name,
            }
  end
end

do
  Default.data.user.active = {
    __refines__ = {
      this.data.user,
    },
  }
  local checks = Default.data.user.active.checks
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local user    = request [key]
    return  user.status == "active"
        or  nil, {
              _    = i18n ["check:user:not-active"],
              name = user.username,
            }
  end
end

do
  Default.data.user.suspended = {
    __refines__ = {
      this.data.user,
    },
  }
  local checks = Default.data.user.suspended.checks
  checks [Layer.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local user    = request [key]
    return  user.status == "suspended"
        or  nil, {
              _    = i18n ["check:user:not-suspended"],
              name = user.username,
            }
  end
end

-- Project name
-- ------------
do
  Default.data.project = {
    __refines__ = {
      this.data.project.name,
    },
    name = {
      min_size = 1,
      max_size = 32,
      __refines__ = {
        this.data.string.trimmed,
      }
    }
  }
  local checks = Default.data.project.name.checks
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
  local checks = Default.data.project.checks
  checks [Layer.size (checks)+1] = function (t)
    local store   = t.store
    local request = t.request
    local key     = t.key
    local name    = request [key]
    return  Store.exists (store.project, name)
        or  nil, {
              _    = i18n ["check:project:miss"],
              name = name,
            }
  end
  checks [Layer.size (checks)+1] = function (t)
    local store   = t.store
    local request = t.request
    local key     = t.key
    local name    = request [key]
    local project = store.project [name]
    request [key] = project
    return  project.type == "project"
        or  nil, {
              _    = i18n ["check:project:not-project"],
              name = name,
            }
  end
end

-- Password
-- --------
do
  Default.data.password = {
    min_size = 1,
    max_size = 128,
    __refines__ = {
      this.data.string.trimmed,
    }
  }
end

do
  Default.data.password.checked = {
    __refines__ = {
      this.data.password,
    }
  }
end

-- Email
-- -----
do
  Default.data.email = {
    max_size = 128,
    __refines__ = {
      this.data.string.trimmed,
    }
  }
  local checks = Default.data.email.checks
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
  Default.data.name = {
    min_size = 1,
    max_size = 128,
    __refines__ = {
      this.data.string.trimmed,
    }
  }
end

-- Organization
-- ------------
do
  Default.data.organization = {
    min_size = 1,
    max_size = 128,
    __refines__ = {
      this.data.string.trimmed,
    }
  }
end

-- Description
-- -----------
do
  Default.data.description = {
    min_size = 1,
    max_size = 4096,
    __refines__ = {
      this.data.string.trimmed,
    }
  }
end

-- Terms of Services Digest
-- ------------------------
do
  Default.data.tos = {
    __refines__ = {
      this.data.string.trimmed,
    },
  }
  Default.data.tos.digest = {
    __refines__ = {
      this.data.string.trimmed,
    },
    min_size = 64,
    max_size = 64,
  }
  local checks = Default.data.tos.digest.checks
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
  Default.data.token = {
    __refines__ = {
      this.data.string.trimmed,
    },
  }
  local checks = Default.data.token.checks
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
  Default.data.token.administration = {
    __refines__ = {
      this.data.token,
    },
  }
  local checks = Default.data.token.administration.checks
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
  Default.data.token.validation = {
    __refines__ = {
      this.data.token,
    },
  }
  local checks = Default.data.token.validation.checks
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
    local user     = store.user [username]
    request [key].user = user
    return  nil
       and  user.type == "user"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end

-- Authentication Token
-- --------------------
do
  Default.data.token.authentication = {
    __refines__ = {
      this.data.token,
    },
  }
  local checks = Default.data.token.authentication.checks
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
    local user     = store.user [username]
    request [key].user = user
    return  user
       and  user.type   == "user"
       and  user.status == "active"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end
