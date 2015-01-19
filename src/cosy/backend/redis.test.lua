require "busted"

local assert = require "luassert"

local Platform = require "cosy.platform"
Platform.logger.enabled = false

local Backend  = require "cosy.backend.redis"

describe ("Redis backend", function ()

  setup (function ()
    Backend.pool [1] = require "fakeredis" .new ()
    Backend.pool [1].transaction = function (client, opt, f)
      return f (client)
    end
    Backend.pool [1]:hset ("/username", "secrets", Platform.json.encode {
      password = Platform.password.hash "password",
    })
  end)

  describe ("'information' method", function ()

    it ("should return information", function ()
      local info = Backend:information ()
      assert.is_truthy (type (info) == "table")
    end)
  end)

  describe ("'authenticate' method", function ()

    it ("does not authenticate a missing username", function ()
      assert.has.error (function ()
        Backend:authenticate {
          username = "missing",
          password = "password",
        }
      end)
    end)

    it ("does not authenticate an erroneous username/password", function ()
      assert.has.error (function ()
        Backend:authenticate {
          username = "username",
          password = "erroneous",
        }
      end)
    end)

    it ("authenticates a valid username/password", function ()
      assert.has.no.error (function ()
        Backend:authenticate {
          username = "username",
          password = "password",
        }
      end)
      assert.are.equal (Backend.username, "username")
    end)
  end)

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

end)