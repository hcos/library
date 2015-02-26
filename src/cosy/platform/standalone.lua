require "cosy.util.string"

local Platform = setmetatable ({
    _pending = {},
    _running = {},
  }, {
  __index = function (self, key)
    local running = self._running [key]
    local pending = self._pending [key]
    if running then
      return running
    elseif pending then
      self._running [key] = {}
      pending ()
      return self._running [key]
    else
      return nil
    end
  end,
  __newindex = function (self, key, value)
    self._running [key] = value
  end,
})
function Platform:register (key, value)
  assert (type (key) == "string" and type (value) == "function")
  self._pending [key] = value
end

-- Logger
-- ======
Platform:register ("logger", function ()
  if pcall (function ()
    local logging   = require "logging"
    logging.console = require "logging.console"
    local backend   = logging.console "%level %message\n"
    function Platform.logger.debug (t)
      if Platform.logger.enabled then
        backend:debug (Platform.i18n (t [1], t))
      end
    end
    function Platform.logger.info (t)
      if Platform.logger.enabled then
        backend:info (Platform.i18n (t [1], t))
      end
    end
    function Platform.logger.warning (t)
      if Platform.logger.enabled then
        backend:warn (Platform.i18n (t [1], t))
      end
    end
    function Platform.logger.error (t)
      if Platform.logger.enabled then
        backend:error (Platform.i18n (t [1], t))
      end
    end
  end) then
    Platform.logger.enabled = true
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "logger",
      dependency = "lualogging",
    }
  elseif pcall (function ()
    local backend = require "log".new ("debug",
      require "log.writer.console.color".new ()
    )
    function Platform.logger.debug (t)
      if Platform.logger.enabled then
        backend.notice (Platform.i18n (t [1], t))
      end
    end
    function Platform.logger.info (t)
      if Platform.logger.enabled then
        backend.info (Platform.i18n (t [1], t))
      end
    end
    function Platform.logger.warning (t)
      if Platform.logger.enabled then
        backend.warning (Platform.i18n (t [1], t))
      end
    end
    function Platform.logger.error (t)
      if Platform.logger.enabled then
        backend.error (Platform.i18n (t [1], t))
      end
    end
  end) then
    Platform.logger.enabled = true
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "logger",
      dependency = "lua-log",
    }
  else
    function Platform.logger.debug ()
    end
    function Platform.logger.info ()
    end
    function Platform.logger.warning ()
    end
    function Platform.logger.error ()
    end
  end
end)

-- Internationalization
-- ====================
Platform:register ("i18n", function ()
  Platform.i18n = require "i18n"
  Platform.i18n.load { en = require "cosy.i18n.en" }
  if pcall (require, "lfs") then
    local lfs = require "lfs"
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "i18n",
      dependency = "i18n",
    }
    for path in package.path:gmatch "([^;]+)" do
      if path:sub (-5) == "?.lua" then
        path = path:sub (1, #path - 5) .. "cosy/i18n/"
        if lfs.attributes (path, "mode") == "directory" then
          for file in lfs.dir (path) do
            if lfs.attributes (path .. file, "mode") == "file"
            and file:sub (1,1) ~= "." then
              local name = file:gsub (".lua", "")
              Platform.i18n.load { name = require ("cosy.i18n." .. name) }
              Platform.logger.debug {
                "platform:available-locale",
                locale  = name,
              }
            end
          end
        end
      end
    end
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "i18n",
    }
    error "Missing dependency"
  end
end)

-- Foreign Function Interface
-- ==========================
--[[
if _G.jit then
  Platform.ffi = require "ffi"
  Platform.logger.debug (Platform.i18n ("platform:available-dependency", {
    component  = "ffi",
    dependency = "luajit",
  }))
elseif pcall (function ()
  Platform.ffi = require "luaffi"
end) then
  Platform.logger.debug (Platform.i18n ("platform:available-dependency", {
    component  = "ffi",
    dependency = "luaffi",
  }))
else
  Platform.logger.debug (Platform.i18n ("platform:missing-dependency", {
    component  = "ffi",
  }))
  error "Missing dependency"
end
--]]

-- Unique ID generator
-- ===================
Platform:register ("unique", function ()
  math.randomseed (os.time ())
  function Platform.unique.id ()
    error "Not implemented yet"
  end
  function Platform.unique.uuid ()
    local run    = io.popen ("uuidgen", "r")
    local result = run:read "*l"
    run:close ()
    return result
  end
  function Platform.unique.key ()
    return Platform.md5.digest (tostring (math.random ()))
  end
end)

-- Table dump
-- ==========
Platform:register ("table", function ()
  if pcall (function ()
    local serpent = require "serpent"
    function Platform.table.encode (t)
      return serpent.dump (t, {
        sortkeys = false,
        compact  = true,
        fatal    = true,
        comment  = false,
      })
    end
    function Platform.table.representation (t)
      return serpent.line (t, {
        sortkeys = true,
        compact  = true,
        fatal    = true,
        comment  = false,
        nocode   = true,
      })
    end
    function Platform.table.decode (s)
      return serpent.load (s, {
        safe = true,
      })
    end
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "table dump",
      dependency = "serpent",
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "table dump",
    }
    error "Missing dependency"
  end
end)

-- JSON
-- ====
Platform:register ("json", function ()
  if pcall (function ()
    Platform.json = require "cjson" .new ()
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "json",
      dependency = "cjson",
    }
  elseif pcall (function ()
    _G.always_try_using_lpeg = true
    Platform.json = require "dkjson"
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "json",
      dependency = "dkjson+lpeg",
    }
  elseif pcall (function ()
    _G.always_try_using_lpeg = false
    Platform.json = require "dkjson"
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "json",
      dependency = "dkjson",
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "JSON",
    }
    error "Missing dependency"
  end
end)

-- YAML
-- ====
Platform:register ("yaml", function ()
  if pcall (function ()
    local yaml = require "lyaml"
    Platform.yaml = {
      encode = yaml.dump,
      decode = yaml.load,
    }
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "yaml",
      dependency = "lyaml",
    }
  elseif pcall (function ()
    local yaml = require "yaml"
    Platform.yaml = {
      encode = yaml.dump,
      decode = yaml.load,
    }
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "yaml",
      dependency = "yaml",
    }
  elseif pcall (function ()
    local yaml = require "luayaml"
    Platform.yaml = {
      encode = yaml.dump,
      decode = yaml.load,
    }
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "yaml",
      dependency = "luayaml",
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "yaml",
    }
    error "Missing dependency"
  end
end)

-- Compression
-- ===========
Platform:register ("compression", function ()

  Platform.compression.available = {}
  do
    Platform.compression.available.id = {
      compress   = function (x) return x end,
      decompress = function (x) return x end,
    }
    Platform.logger.debug {
      "platform:available-compression",
      compression = "none",
    }
  end
  pcall (function ()
    Platform.compression.available.lz4 = require "lz4"
    Platform.logger.debug {
      "platform:available-compression",
      compression = "lz4",
    }
  end)
  pcall (function ()
    Platform.compression.available.snappy = require "snappy"
    Platform.logger.debug {
      "platform:available-compression",
      compression = "snappy",
    }
  end)

  function Platform.compression.format (x)
    return x:match "^(%w+):"
  end

  function Platform.compression.compress (x, format)
    return format .. ":" .. Platform.Compressions[format].compress (x)
  end
  function Platform.compression.decompress (x)
    local format = Platform.compression.format (x)
    local Compression = Platform.Compressions[format]
    return Compression
       and Compression.decompress (x:sub (#format+2))
        or error ("Compression format '%{format}' is not available" % {
          format = format,
        })
  end
end)

-- Password Hashing
-- ================
Platform:register ("password", function ()
  local Configuration = require "cosy.configuration" .whole
  if pcall (function ()
    local bcrypt = require "bcrypt"
    local function compute_rounds ()
      for _ = 1, 5 do
        local rounds = 5
        while true do
          local start = Platform.time ()
          bcrypt.digest ("some random string", rounds)
          local delta = Platform.time () - start
          if delta > Configuration.data.password.time._ then
            Platform.password.rounds = math.max (Platform.password.rounds or 0, rounds)
            break
          end
          rounds = rounds + 1
        end
      end
      return Platform.password.rounds
    end
    compute_rounds ()
    function Platform.password.hash (password)
      return bcrypt.digest (password, Platform.password.rounds)
    end
    function Platform.password.verify (password, digest)
      return bcrypt.verify (password, digest)
    end
    function Platform.password.is_too_cheap (digest)
      return tonumber (digest:match "%$%w+%$(%d+)%$") < Platform.password.rounds
    end
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "password hashing",
      dependency = "bcrypt",
    }
    Platform.logger.debug {
      "platform:bcrypt-rounds",
      count = Platform.password.rounds,
      time  = Configuration.data.password.time._ * 1000,
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "password hashing",
    }
    error "Missing dependency"
  end
end)

-- MD5
-- ===
Platform:register ("md5", function ()
  if pcall (function ()
    Platform.md5 = require "md5"
  end) then
    Platform.md5.digest = Platform.md5.sumhexa
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "md5",
      dependency = "md5",
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "md5",
    }
    error "Missing dependency"
  end
end)

-- Redis
-- =====
Platform:register ("redis", function ()
  if _G.__TEST__ then
    if pcall (function ()
      Platform.redis = require "fakeredis" .new ()
      Platform.redis.is_fake     = true
      Platform.redis.connect     = function ()
        return Platform.redis
      end
      Platform.redis.expireat    = function ()
      end
      Platform.redis.persist     = function ()
      end
      Platform.redis.multi       = function ()
      end
      Platform.redis.transaction = function (client, _, f)
        return f (client)
      end
    end) then
      Platform.logger.debug {
        "platform:available-dependency",
        component  = "redis",
        dependency = "fakeredis",
      }
    else
      Platform.logger.debug {
        "platform:missing-dependency",
        component  = "redis",
      }
      error "Missing dependency"
    end
  else
    if pcall (function ()
      Platform.redis = require "redis"
    end) then
      Platform.logger.debug {
        "platform:available-dependency",
        component  = "redis",
        dependency = "redis-lua",
      }
    else
      Platform.logger.debug {
        "platform:missing-dependency",
        component  = "redis",
      }
      error "Missing dependency"
    end
  end
end)

-- Random
-- ======
Platform:register ("random", function ()
  math.randomseed (Platform.time ())
  Platform.random = math.random
  Platform.logger.debug {
    "platform:available-dependency",
    component  = "random",
    dependency = "math.random",
  }
end)

-- Time
-- ====
Platform:register ("time", function ()
  if pcall (function ()
    local socket  = require "socket"
    Platform.time = socket.gettime
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "time",
      dependency = "luasocket",
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "time",
    }
    error "Missing dependency"
  end
end)

-- Token
-- =====
Platform:register ("token", function ()
  if pcall (function ()
    local jwt           = require "luajwt"
    local Configuration = require "cosy.configuration" .whole
    local Internal      = require "cosy.configuration" .internal
    if Configuration.token.secret._ == nil then
      Platform.logger.debug {
        "platform:no-token-secret",
      }
      error "No token secret"
    end
    Internal.token.algorithm._ = "HS512"
    Internal.token.validity._ = 600 -- seconds
    Platform.token = {}
    function Platform.token.encode (contents)
      local token = {}
      token.iat = Platform.time ()
      token.nbf = token.iat
      token.exp = token.nbf + Configuration.token.validity._
      token.iss = Configuration.server.name._
      token.aud = nil
      token.sub = "cosy:token"
      token.jti = Platform.md5.digest (tostring (token.iat + Platform.random ()))
      token.contents = contents
      local key       = Configuration.token.secret._
      local algorithm = Configuration.token.algorithm._
      local result, err = jwt.encode (token, key, algorithm)
      if not result then
        error (err)
      end
      return result
    end
    function Platform.token.decode (s)
      local key       = Configuration.token.secret._
      local algorithm = Configuration.token.algorithm._
      local result, err = jwt.decode (s, key, algorithm)
      if not result then
        error (err)
      end
      return result.contents
    end
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "token",
      dependency = "jwt",
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "token",
    }
    error "Missing dependency"
  end
end)

-- Configuration
-- =============
Platform:register ("configuration", function ()
  if _G.__TEST__ then
    Platform.configuration.paths = {}
    function Platform.configuration.read ()
      return nil
    end
  else
    Platform.configuration.paths = {
      "/etc",
      os.getenv "HOME" .. "/.cosy",
      os.getenv "PWD",
    }
    function Platform.configuration.read (path)
      local handle = io.open (path, "r")
      if handle ~=nil then
        local content = handle:read "*all"
        io.close (handle)
        return content
      else
        return nil
      end
    end
  end
end)

-- Scheduler
-- =========
Platform:register ("scheduler", function ()
  Platform.scheduler = require "cosy.util.scheduler" .create ()
end)

-- Email
-- =====
Platform:register ("email", function ()
  if _G.__TEST__ then
    Platform.email = {}
    Platform.email.send = function (t)
      Platform.email.last_sent = t
    end
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "email",
      dependency = "mock",
    }
  else
    local Email = require "cosy.util.email"
    Platform.email.send = Email.send
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "email",
      dependency = "cosy.util.email",
    }
    if not Email.discover () then
      Platform.logger.warning {
        "platform:no-smtp",
      }
    else
      local Configuration = require "cosy.configuration" .whole
      Platform.logger.debug {
        "platform:smtp",
        host     = Configuration.smtp.host._,
        port     = Configuration.smtp.port._,
        method   = Configuration.smtp.method._,
        protocol = Configuration.smtp.protocol._,
      }
    end
  end
end)

return Platform