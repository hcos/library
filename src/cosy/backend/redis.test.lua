require "busted"

local assert = require "luassert"

local Platform      = require "cosy.platform"
Platform.logger.enabled = false

local Configuration = require "cosy.configuration"
Configuration.data.password.time = 0.001
Configuration.data.password.min_size = 5

local Backend       = require "cosy.backend.redis"

describe ("Redis backend", function ()

  local session

  setup (function ()
    Backend.pool [1] = require "fakeredis" .new ()
    Backend.pool [1].transaction = function (client, opt, f)
      return f (client)
    end
    Backend.pool [1].multi = function () end
    Backend.pool [1]:hset ("/username", "metadata", Platform.json.encode {
      type   = "user",
      locale = "en",
    })
    Backend.pool [1]:hset ("/username", "secrets", Platform.json.encode {
      password = Platform.password.hash "password",
    })
    session = setmetatable ({}, Backend)
  end)

  before_each (function()
    Configuration:reload ()
    Configuration.data.username.min_size = 2
    Configuration.data.username.max_size = 10
    Configuration.data.password.min_size = 2
    Configuration.data.password.max_size = 10
  end)

  describe ("authenticate method", function ()

    it ("requires a string username", function ()
      assert.has.error (function ()
        session:authenticate {
          username = 123456,
          password = "password",
        }
      end)
    end)

    it ("requires a username with a minimum size", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "1",
          password = "password",
        }
      end)
    end)
    
    it ("requires a username with a maximum size", function ()
      Configuration.data.username.max_size = 5
      assert.has.error (function ()
        session:authenticate {
          username = "1234567890",
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

    it ("does not authenticate a non-existing username", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "missing",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate a non-user", function ()
      Backend.pool [1]:hset ("/something", "metadata", Platform.json.encode {
        type   = "other",
        locale = "en",
      })
      Backend.pool [1]:hset ("/something", "secrets", Platform.json.encode {
        password = Platform.password.hash "password",
      })
      assert.has.error (function ()
        session:authenticate {
          username = "something",
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

    it ("requires a password with a minimum size", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "username",
          password = "1",
        }
      end)
    end)

    it ("requires a password with a maximum size", function ()
      assert.has.error (function ()
        session:authenticate {
          username = "username",
          password = "1234567890",
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