               require "cosy.util.string"
local ignore = require "cosy.util.ignore"

local global = _G

local Platform = setmetatable ({
    _pending = {},
  }, {
  __index = function (self, key)
    local pending = rawget (self._pending, key)
    if pending then
      rawset (self, key, {})
      pending ()
      return self [key]
    else
      return nil
    end
  end,
  __newindex = function (self, key, value)
    assert (type (key) == "string" and type (value) == "function")
    self._pending [key] = value
  end,
})

-- Logger
-- ======
Platform.logger = function ()
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
end

-- Internationalization
-- ====================
Platform.i18n = function ()
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
end

-- Foreign Function Interface
-- ==========================
--[[
if global.jit then
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
Platform.unique = function ()
  function Platform.unique.id ()
    error "Not implemented yet"
  end
  function Platform.unique.uuid ()
    local run    = io.popen ("uuidgen", "r")
    local result = run:read "*l"
    run:close ()
    return result
  end
end

-- Table dump
-- ==========
Platform.table = function ()
  if pcall (function ()
    local serpent = require "serpent"
    function Platform.table.encode (t)
      return serpent.dump (t)
    end
    function Platform.table.decode (s)
      return loadstring (s) ()
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
end

-- JSON
-- ====
Platform.json = function ()
  if pcall (function ()
    Platform.json = require "cjson"
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "json",
      dependency = "cjson",
    }
  elseif pcall (function ()
    global.always_try_using_lpeg = true
    Platform.json = require "dkjson"
  end) then
    Platform.logger.debug {
      "platform:available-dependency",
      component  = "json",
      dependency = "dkjson+lpeg",
    }
  elseif pcall (function ()
    global.always_try_using_lpeg = false
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
end

-- YAML
-- ====
Platform.yaml = function ()
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
end

-- Compression
-- ===========
Platform.compression = function ()

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
  ignore (pcall (function ()
    Platform.compression.available.lz4 = require "lz4"
    Platform.logger.debug {
      "platform:available-compression",
      compression = "lz4",
    }
  end))
  ignore (pcall (function ()
    Platform.compression.available.snappy = require "snappy"
    Platform.logger.debug {
      "platform:available-compression",
      compression = "snappy",
    }
  end))

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
end

-- Password Hashing
-- ================
Platform.password = function ()
  local Configuration = require "cosy.configuration"
  if pcall (function ()
    local bcrypt = require "bcrypt"
    local function compute_rounds ()
      for _ = 1, 5 do
        local rounds = 5
        while true do
          local start = Platform.time ()
          bcrypt.digest ("some random string", rounds)
          local delta = Platform.time () - start
          if delta > Configuration.data.password.time then
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
      time  = Configuration.data.password.time * 1000,
    }
  else
    Platform.logger.debug {
      "platform:missing-dependency",
      component  = "password hashing",
    }
    error "Missing dependency"
  end
end

-- MD5
-- ===
Platform.md5 = function ()
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
end

-- Redis
-- =====
Platform.redis = function ()
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

-- Time
-- ====
Platform.time = function ()
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
end

-- Configuration
-- =============
Platform.configuration = function ()
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

-- Scheduler
-- =========
Platform.scheduler = function ()
  Platform.scheduler = require "cosy.util.scheduler" .create ()
end

-- Email
-- =====
Platform.email = function ()
  local Email = require "cosy.util.email"
  if not Email.discover () then
    Platform.logger.warning ("No SMTP server discovered, sending of emails will not work.")
    error "SMTP missing"
  end
  local Configuration = require "cosy.configuration"
  Platform.logger.debug ("SMTP on ${host}:${port} uses ${method} (encrypted with ${protocol})." % {
    host     = Configuration.smtp.host,
    port     = Configuration.smtp.port,
    method   = Configuration.smtp.method,
    protocol = Configuration.smtp.protocol,
  })
  Platform.email.send = Email.send
end

return Platform