require "busted"

local assert = require "luassert"

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
local Backend       = require "cosy.backend.redis"

Configuration.security.password_computation = 0.001
Configuration.security.password_size = 5
Platform.logger.enabled = false

describe ("Redis backend", function ()

  local session

  setup (function ()
    Backend.pool [1] = require "fakeredis" .new ()
    Backend.pool [1].transaction = function (client, opt, f)
      return f (client)
    end
    Backend.pool [1]:hset ("/username", "metadata", Platform.json.encode {
      locale = "en",
      type   = "user",
    })
    Backend.pool [1]:hset ("/username", "secrets", Platform.json.encode {
      password = Platform.password.hash "password",
    })
    session = setmetatable ({}, Backend)
  end)

  describe ("'authenticate' method", function ()

    it ("requires a string username", function ()
      assert.has.error (function ()
        session:authenticate {
          username = 123456,
          password = "password",
        }
      end)
    end)

    it ("requires a (trimmed) non-empty username", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "     ",
          password = "password",
        }
      end)
    end)

    it ("requires a username containing only alphanumerical characters", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "abc!def",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate non-existing username", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "missing",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate an erroneous username/password", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "username",
          password = "erroneous",
        }
      end)
    end)

    it ("does not authenticate a too small password", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "username",
          password = "pass",
        }
      end)
    end)

    it ("authenticates a valid username/password", function ()
      assert.has.no.error (function ()
        session:authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (session.username, "username")
    end)

    it ("rehashes password if necessary", function ()
      Platform.password.rounds = 4
      Backend.pool [1]:hset ("/username", "secrets", Platform.json.encode {
        password = Platform.password.hash "password",
      })
      Platform.password.rounds = 5
      local s = spy.on (Platform.password, "hash")
      assert.has.no.error (function ()
        session:authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.spy (s).was_called ()
    end)

    it ("does not rehash password unless necessary", function ()
      Platform.password.rounds = 5
      Backend.pool [1]:hset ("/username", "secrets", Platform.json.encode {
        password = Platform.password.hash "password",
      })
      Platform.password.rounds = 5
      local s = spy.on (Platform.password, "hash")
      assert.has.no.error (function ()
        session:authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.spy (s).was_not_called ()
    end)

    it ("sets the session locale", function ()
      assert.has.no.error (function ()
        session:authenticate {
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