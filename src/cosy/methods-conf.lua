local Default = require "cosy.configuration-layers".default
local Layer   = require "layeredata"


Default.expiration = {
  validation     =  1 * 3600, -- 1 hour
  authentication =  1 * 3600 ,-- 1 hour
  administration =  99 * 365 * 24 * 3600, -- 99 years
}

Default.reputation = {
  initial = 10,
  suspend = 50,
  release = 50,
}

Default.resource = {
  email = {
    key = "email:{{{key}}}",
  },
  token = {
    key = "token:{{{key}}}",
  },
  user = {
    key = "user:{{{key}}}",
    template = {
      _             = { access = "hidden"  },
      _avatar       = { access = "public"  },
      _checked      = { access = "private" },
      _email        = { access = "private" },
      _homepage     = { access = "public"  },
      _lastseen     = { access = "private" },
      _locale       = { access = "private" },
      _name         = { access = "public"  },
      _organization = { access = "public"  },
      _password     = { access = "hidden"  },
      _position     = { access = "private" },
      _reputation   = { access = "public"  },
      _status       = { access = "hidden"  },
      _tos_digest   = { access = "private" },
      _type         = { access = "hidden"  },
      _username     = { access = "public"  },
    }
  },
  project = {
    key = "project:{{{key}}}",
  },
}
