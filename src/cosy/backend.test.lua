                    require "busted"
local assert      = require "luassert"

local Platform      = require "cosy.platform"
Platform.configuration.paths = {}
Platform.logger.enabled = false

local Configuration = require "cosy.configuration" . whole

Platform:register ("email", function ()
  Platform.email = {}
  Platform.email.send = function () end
end)
Platform:register ("redis", function ()
  Configuration.redis.pool_size = 1
  Platform.redis                = require "fakeredis" .new ()
  Platform.redis.is_fake        = true
  Platform.redis.connect        = function ()
    return Platform.redis
  end
  Platform.redis.multi          = function ()
  end
  Platform.redis.transaction    = function (client, _, f)
    return f (client)
  end
end)

local Backend = require "cosy.backend"

do
  local say = require "say"

  local function raises (state, arguments)
    if  type (arguments [1]) ~= "function"
    and type (arguments [2]) ~= "string" then
      return false
    end
    local ok, err = pcall (arguments [1])
    if ok then
      return false
    elseif type (err) ~= "table" then
      arguments [3] = err
      arguments [4] = ""
      return false
    else
      arguments [3] = err.status or ""
      arguments [4] = err.reason or ""
      return err.status == arguments [2]
    end
  end

  say:set ("assertion.raises.positive", "Expected %s to throw %s error, but received %s: %s.")
  say:set ("assertion.raises.negative", "Expected %s to not throw %s error.")
  assert:register ("assertion", "raises", raises,
                   "assertion.raises.positive",
                   "assertion.raises.negative")
end

describe ("...", function ()

  local session
  local license     = (Platform.i18n.translate "license"):trim ()
  local license_md5 = Platform.md5.digest (license)

  before_each (function()
    Configuration.data.password.time     = 0.001
    Configuration.data.username.min_size = 2
    Configuration.data.username.max_size = 10
    Configuration.data.password.min_size = 2
    Configuration.data.password.max_size = 10
    Configuration.data.name.min_size     = 2
    Configuration.data.name.max_size     = 10
    Configuration.data.email.max_size    = 10
    Platform.redis:flushdb ()
    session = setmetatable ({}, Backend)
  end)

  describe ("user creation", function ()
    
    it ("requires a string username", function ()
      assert.raises (function ()
        session.create_user {
          username = 123456,
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)

    it ("requires a username with a minimum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "a",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)

    it ("requires a username with a maximum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "abcdefghijkl",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)

    it ("requires a username containing only alphanumerical characters", function ()
      assert.raises (function ()
        session.create_user {
          username = "abc!def",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)

    it ("requires a password with a minimum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "p",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)
    
    it ("requires a password with a maximum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "abcdefghijkl",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
   end)

    it ("requires a name with a minimum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "a@b.fr",
          name     = "U",
          locale   = "en",
        }
      end, "check:error")
    end)
    
    it ("requires a name with a maximum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "a@b.fr",
          name     = "User Long Name",
          locale   = "en",
        }
      end, "check:error")
    end)

    it ("requires an email with a maximum size", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "username@username.fr",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)
  
    it ("requires an email matching the email pattern", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "username@username",
          name     = "User Name",
          locale   = "en",
        }
      end, "check:error")
    end)
  
    it ("requires a locale matching the locale pattern", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "G",
        }
      end, "check:error")
    end)

    it ("does not create a user when already authenticated", function ()
      local extracted     = {}
      Platform.email.send = function (t)
        for word in t.body:gmatch "<(%x+)>" do
          if #word == 32 then
            extracted.validation_key = word
          end
        end
      end
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
        session.validate_user {
          username       = "username",
          validation_key = extracted.validation_key,
        }
        session.authenticate {
          username = "username",
          password = "password",
          license  = session.license {
            locale   = "en",
          }.digest,
        }
        session.create_user {
          username = "othername",
          password = "password",
          email    = "c@b.fr",
          name     = "Other Name",
          locale   = "en",
        }
      end, "create-user:connected-already")
    end)

    it ("does not create a user whose email is already registered", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
        session.create_user {
          username = "othername",
          password = "password",
          email    = "a@b.fr",
          name     = "Other Name",
          locale   = "en",
        }
      end, "create-user:email-already")
    end)

    it ("does not create a user whose username is already registered", function ()
      assert.raises (function ()
        session.create_user {
          username = "username",
          password = "password",
          email    = "a@b.fr",
          name     = "User Name",
          locale   = "en",
        }
        session.create_user {
          username = "username",
          password = "password",
          email    = "c@b.fr",
          name     = "Other Name",
          locale   = "en",
        }
      end, "create-user:username-already")
    end)
  end)


  describe ("authenticate method", function ()

    local authenticate

    before_each (function()
      Backend.pool [1]:set ("/username", Platform.json.encode {
        type             = "user",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = license_md5,
      })
      authenticate = session.authenticate
    end)
--[==[
    it ("requires a string username", function ()
      assert.raises (function ()
        authenticate {
          username = 123456,
          password = "password",
        }
      end, "check:error")
    end)

    it ("requires a username with a minimum size", function ()
      assert.raises (function ()
        authenticate {
          username = "a",
          password = "password",
        }
      end, "check:error")
    end)
    
    it ("requires a username with a maximum size", function ()
      assert.raises (function ()
        authenticate {
          username = "abcdefghijk",
          password = "password",
        }
      end, "check:error")
    end)

    it ("requires a username containing only alphanumerical characters", function ()
      assert.raises (function ()
        authenticate {
          username = "abc!def",
          password = "password",
        }
      end, "check:error")
    end)

    it ("does not authenticate a non-existing username", function ()
      assert.raises (function ()
        authenticate {
          username = "missing",
          password = "password",
        }
      end, "authenticate:non-existing")
    end)

    it ("does not authenticate a non-user", function ()
      Backend.pool [1]:set ("/something", Platform.json.encode {
        type             = "other",
        locale           = "en",
        password         = Platform.password.hash "password",
        accepted_license = license_md5,
      })
      assert.raises (function ()
        authenticate {
          username = "something",
          password = "password",
        }
      end, "authenticate:non-user")
    end)

    it ("does not authenticate an erroneous username/password", function ()
      assert.raises (function ()
        authenticate {
          username = "username",
          password = "erroneous",
        }
      end, "authenticate:erroneous")
    end)

    it ("requires a password with a minimum size", function ()
      assert.raises (function ()
        authenticate {
          username = "username",
          password = "1",
        }
      end, "check:error")
    end)

    it ("requires a password with a maximum size", function ()
      assert.raises (function ()
        authenticate {
          username = "username",
          password = "abcdefghijkl",
        }
      end, "check:error")
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
      assert.raises (function ()
        authenticate {
          username = "username",
          password = "password",
        }
        authenticate {
          response = "ABCDE",
        }
      end, "license:reject")
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
  
    it ("should execute in less than 5 milliseconds (hash excepted)", function ()
      Platform.password.rounds = 4
      local n_iterations = 100
      local password_duration
      do
        local start = Platform.time ()
        for _ = 1, n_iterations do
          Platform.password.hash "password"
        end
        password_duration = Platform.time () - start
      end
      local authenticate_duration
      do
        local start = Platform.time ()
        for _ = 1, n_iterations do
          session.username = nil
          session.authenticate {
            username = "username",
            password = "password",
          }
        end
        authenticate_duration = Platform.time () - start
      end
      local average = (authenticate_duration - password_duration) / n_iterations
      assert.is_truthy (average < 0.005)
    end)
--]==]
  end)
  describe ("'create_user' method", function ()

--[==[
    it ("does not create a user when the email is already registered", function ()
      assert.has.error (function ()
      end)
    end)
  
    it ("does not create a user when the username exists already", function ()
      assert.has.error (function ()
      end)
    end)
  
    it ("asks for license acceptance on license change", function ()
    end)

    it ("creates a user with license acceptance", function ()
    end)

    it ("does not create a user with license refusal", function ()
    end)

    it ("stores license acceptance", function ()
    end)

    it ("send the validation key to the email address", function ()
    end)

    it ("send the validation key to the email address", function ()
    end)
  --]==]
  end)

end)