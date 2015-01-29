                    require "busted"
local assert      = require "luassert"
local before_each = _G.before_each
local describe    = _G.describe
local it          = _G.it
local spy         = _G.spy

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
local Backend       = require "cosy.backend.redis"
Platform.logger.enabled = false

describe ("Redis backend", function ()

  describe ("authenticate method", function ()

    local session
    local authenticate
    local license     = (Platform.i18n.translate "license"):trim ()
    local license_md5 = Platform.md5.digest (license)

    before_each (function()
      Configuration:reload ()
      Configuration.data.password.time = 0.001
      Configuration.data.password.min_size = 5
      Configuration.data.username.min_size = 2
      Configuration.data.username.max_size = 10
      Configuration.data.password.min_size = 2
      Configuration.data.password.max_size = 10
      Backend.pool [1] = require "fakeredis" .new ()
      Backend.pool [1].transaction = function (client, _, f)
        return f (client)
      end
      Backend.pool [1].multi = function () end
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = license_md5,
      })
      session      = setmetatable ({}, Backend)
      authenticate = session.authenticate
    end)

    it ("requires a string username", function ()
      assert.has.error (function ()
        authenticate {
          username = 123456,
          password = "password",
        }
      end)
    end)

    it ("requires a username with a minimum size", function ()
      assert.has.error (function ()
        authenticate {
          username = "1",
          password = "password",
        }
      end)
    end)
    
    it ("requires a username with a maximum size", function ()
      Configuration.data.username.max_size = 5
      assert.has.error (function ()
        authenticate {
          username = "1234567890",
          password = "password",
        }
      end)
    end)

    it ("requires a username containing only alphanumerical characters", function ()
      assert.has.error (function ()
        authenticate {
          username = "abc!def",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate a non-existing username", function ()
      assert.has.error (function ()
        authenticate {
          username = "missing",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate a non-user", function ()
      Backend.pool [1]:set ("/something", Platform.json.encode {
        type             = "other",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = license_md5,
      })
      assert.has.error (function ()
        authenticate {
          username = "something",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate an erroneous username/password", function ()
      assert.has.error (function ()
        authenticate {
          username = "username",
          password = "erroneous",
        }
      end)
    end)

    it ("requires a password with a minimum size", function ()
      assert.has.error (function ()
        authenticate {
          username = "username",
          password = "1",
        }
      end)
    end)

    it ("requires a password with a maximum size", function ()
      assert.has.error (function ()
        authenticate {
          username = "username",
          password = "1234567890",
        }
      end)
    end)

    it ("authenticates a valid username/password", function ()
      assert.has.no.error (function ()
        authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (session.username, "username")
    end)

    it ("asks for license acceptance if none was accepted previously", function ()
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = nil,
      })
      local _, r
      assert.has.no.error (function ()
        _, r = authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (r.request, "license:accept?")
      assert.are.equal (r.license, license)
      assert.are.equal (r.digest,  license_md5)
    end)

    it ("asks for license acceptance on license change", function ()
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = "ABCDE",
      })
      local _, r
      assert.has.no.error (function ()
        _, r = authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (r.request, "license:accept?")
      assert.are.equal (r.license, license)
      assert.are.equal (r.digest,  license_md5)
    end)

    it ("authenticates a valid username/password with license acceptance", function ()
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = nil,
      })
      assert.has.no.error (function ()
        local _, r = authenticate {
          username = "username",
          password = "password",
        }
        authenticate {
          response = r.digest,
        }
      end)
      assert.are.equal (session.username, "username")
    end)

    it ("does not authenticate a valid username/password with license refusal", function ()
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = nil,
      })
      assert.has.error (function ()
        authenticate {
          username = "username",
          password = "password",
        }
        authenticate {
          response = "ABCDE",
        }
      end)
    end)

    it ("stores license acceptance", function ()
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = nil,
      })
      assert.has.no.error (function ()
        local _, r = authenticate {
          username = "username",
          password = "password",
        }
        authenticate {
          response = r.digest,
        }
      end)
      authenticate     = session.authenticate
      session.username = nil
      assert.has.no.error (function ()
        authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (session.username, "username")
    end)

    it ("rehashes password if necessary", function ()
      Platform.password.rounds = 4
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = license_md5,
      })
      Platform.password.rounds = 5
      local s = spy.on (Platform.password, "hash")
      assert.has.no.error (function ()
        authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.spy (s).was_called ()
    end)

    it ("does not rehash password unless necessary", function ()
      Platform.password.rounds = 5
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = license_md5,
      })
      Platform.password.rounds = 5
      local s = spy.on (Platform.password, "hash")
      assert.has.no.error (function ()
        authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.spy (s).was_not_called ()
    end)

    it ("sets the session locale", function ()
      assert.has.no.error (function ()
        authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (session.locale, "en")
    end)
  end)

--[[
  describe ("'create_user' method", function ()

    it ("does not create an existing user", function ()
      assert.has.error (function ()
        Backend:create_user {
          username = "username",
          password = "password",
        }
      end)
    end)

    it ("creates a valid user", function ()
      assert.has.no.error (function ()
        Backend:create_user {
          username = "myself",
          password = "password",
        }
      end)
    end)
  end)
--]]
end)