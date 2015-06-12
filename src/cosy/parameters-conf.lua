local Configuration = require "cosy.configuration"
local Repository    = require "cosy.repository"
local I18n          = require "cosy.i18n"
local Store         = require "cosy.store"
local Token         = require "cosy.token"
local Internal      = Configuration / "default"

local i18n   = I18n.load "cosy.parameters"
i18n._locale = Configuration.locale._

local function check (value, data)
  local request = {
    key = value,
  }
  for i = 1, Repository.size (data.check) do
    local ok, reason = data.check [i]._ {
      parameter = data,
      request   = request,
      key       = "key",
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
       and  type (value.source ) == "string"
       and  type (value.content) == "string"
        or  nil, {
              _   = i18n ["check:is-table"],
            }
  end
end

-- Position
-- --------

do
  Internal.data.position = {}
  local checks = Internal.data.position.check
  checks [1] = function (t)
    local value = t.request [t.key]
    return  type (value) == "table"
        or  nil, {
              _   = i18n ["check:is-table"],
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
    local value = t.request [t.key]
    return  type (value) == "string"
        or  nil, {
              _   = i18n ["check:is-string"],
            }
  end
  checks [2] = function (t)
    local value = t.request [t.key]
    local size  = t.parameter.min_size._
    return  #value >= size
        or  nil, {
              _     = i18n ["check:min-size"],
              count = size,
            }
  end
  checks [3] = function (t)
    local value = t.request [t.key]
    local size  = t.parameter.max_size._
    return  #value <= size
        or  nil, {
              _     = i18n ["check:max-size"],
              count = size,
            }
  end
end

-- Trimmed String
-- --------------
do
  Internal.data.trimmed = {
    [Repository.refines] = {
      Configuration.data.string,
    }
  }
  local checks = Internal.data.trimmed.check
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

-- Username
-- --------
do
  Internal.data.username = {
    min_size = 1,
    max_size = 32,
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
  local checks = Internal.data.username.check
  checks [Repository.size (checks)+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%w[%w%-_]+$"
        or  nil, {
              _        = i18n ["check:alphanumeric"],
              username = value,
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
      Configuration.data.trimmed,
    }
  }
  local checks = Internal.data.projectname.check
  checks [Repository.size (checks)+1] = function (t)
    local value = t.request [t.key]
    return  value:find "^%w[%w%-_]+$"
        or  nil, {
              _           = i18n ["check:alphanumeric"],
              projectname = value,
            }
  end
end

-- Project
-- -------
do
  Internal.data.project = {
    min_size = 1,
    max_size = 1
             + Configuration.data.username   .max_size._
             + Configuration.data.projectname.max_size._,
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
  local checks = Internal.data.project.check
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local key     = t.key
    local value   = request [key]
    local username, projectname = value:match "^(.-)/(.-)$"
    if not check (username   , Configuration.data.username   )
    or not check (projectname, Configuration.data.projectname)
    then
      return  nil, {
                _           = i18n ["check:project"],
                projectname = value,
              }
    end
    request [key] = {
      rawname     = value,
      username    = username,
      projectname = projectname,
    }
    return true
  end
end

-- Password
-- --------
do
  Internal.data.password = {
    min_size = 1,
    max_size = 128,
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
end

do
  Internal.data.password.checked = {
    [Repository.refines] = {
      Configuration.data.password,
    }
  }
end

-- Email
-- -----
do
  Internal.data.email = {
    max_size = 128,
    [Repository.refines] = {
      Configuration.data.trimmed,
    }
  }
  local checks = Internal.data.email.check
  checks [Repository.size (checks)+1] = function (t)
    local value   = t.request [t.key]
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
      Configuration.data.trimmed,
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
      Configuration.data.trimmed,
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
      Configuration.data.trimmed,
    }
  }
end

-- Locale
-- ------
do
  Internal.data.locale = {
    [Repository.refines] = {
      Configuration.data.trimmed,
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

-- Terms of Services Digest
-- ------------------------
do
  Internal.data.tos_digest = {
    [Repository.refines] = {
      Configuration.data.trimmed,
    },
    min_size = 64,
    max_size = 64,
  }
  local checks = Internal.data.tos_digest.check
  checks [Repository.size (checks)+1] = function (t)
    t.request [t.key] = t.request [t.key]:lower ()
    return  true
  end
  checks [Repository.size (checks)+1] = function (t)
    local value   = t.request [t.key]
    local pattern = "^%x+$"
    return  value:find (pattern)
        or  nil, {
              _          = i18n ["check:tos_digest:pattern"],
              tos_digest = value,
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
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
      Configuration.data.trimmed,
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
    local value   = request [t.key]
    return  value.type == "administration"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local request = t.request
    local value   = request [t.key]
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
    local value   = request [t.key]
    return  value.type == "validation"
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
    local value   = request [t.key]
    return  value.type == "authentication"
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
  checks [Repository.size (checks)+1] = function (t)
    local store    = Store.new ()
    local username = t.request [t.key].username
    local user     = store.users [username]
    local Methods  = require "cosy.methods"
    return  user
       and  user.type   == Methods.Type.user
       and  user.status == Methods.Status.active
        or  nil, {
              _ = i18n ["check:token:invalid"],
            }
  end
end
