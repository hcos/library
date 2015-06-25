local Configuration = require "cosy.configuration"
local Default       = require "cosy.configuration-layers".default

Default.expiration = {
  validation     =  1 * 3600, -- 1 hour
  authentication =  1 * 3600 ,-- 1 hour
  administration =  99 * 365 * 24 * 3600, -- 99 years
}

Default.reputation = {
  initial = 10,
  suspend = 50,
  release = 50,
  filter  = 50,
}

Default.permissions = {
  read  = 1,
  write = 2,
  admin = 3,
}

local Hidden = function ()
  return false
end

local Private = function (user, data, level)
  return user.username == data.username
      or (data.permissions and data.permissions [user.username] >= level)
end

local Public = function (user, data, level)
  if level == Configuration.permissions.read then
    return true
  end
  return user.username == data.username
      or (data.permissions and data.permissions [user.username] >= level)
end

Default.resource = {
  email = {
    key    = "email:{{{key}}}",
    hidden = true,
  },
  token = {
    key    = "token:{{{key}}}",
    hidden = true,
  },
  user = {
    key      = "user:{{{key}}}",
    hidden   = false,
    pattern  = "{{{user}}}",
    template = {
      access        = Public,
      _avatar       = Public,
      _checked      = Private,
      _email        = Private,
      _homepage     = Public,
      _lastseen     = Private,
      _locale       = Private,
      _name         = Public,
      _organization = Public,
      _password     = Hidden,
      _position     = Private,
      _reputation   = Public,
      _status       = Hidden,
      _tos_digest   = Private,
      _type         = Hidden,
      _username     = Public,
    },
  },
  project = {
    key     = "project:{{{key}}}",
    hidden  = false,
    pattern = "{{{user}}}/{{{project}}}",
  },
}
