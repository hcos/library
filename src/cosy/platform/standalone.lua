local Platform = {
  _pending = {},
  _running = {},
}

setmetatable (Platform, {
  __index = function (platform, key)
    local running = platform._running [key]
    local pending = platform._pending [key]
    if running then
      return running
    elseif pending then
      platform._running [key] = {}
      local ok, reason = pcall (pending)
      if ok then
        Platform.logger.debug {
          _         = "platform:available-dependency",
          component = key,
        }
        return platform._running [key]
      else
        local err = {
          _         = "platform:missing-dependency",
          component = key,
          reason    = reason,
        }
        Platform.logger.error (err)
        error (err)
      end
    else
      return nil
    end
  end,
  __newindex = function (platform, key, value)
    platform._running [key] = value
  end,
})
function Platform.register (platform, key, value)
  assert (type (key) == "string" and type (value) == "function")
  platform._pending [key] = value
end

-- Logger
-- ======
Platform:register ("logger", function ()
  local colors    = require "ansicolors"
  local logging   = require "logging"
  logging.console = require "logging.console"
  local backend   = logging.console "%message\n"
  function Platform.logger.debug (t)
    if Platform.logger.enabled then
      backend:debug (colors ("%{dim cyan}" .. (Platform.i18n (t))))
    end
  end
  function Platform.logger.info (t)
    if Platform.logger.enabled then
      backend:info (colors ("%{green}" .. (Platform.i18n (t))))
    end
  end
  function Platform.logger.warning (t)
    if Platform.logger.enabled then
      backend:warn (colors ("%{yellow}" .. (Platform.i18n (t))))
    end
  end
  function Platform.logger.error (t)
    if Platform.logger.enabled then
      backend:error (colors ("%{white redbg}" .. (Platform.i18n (t))))
    end
  end
  Platform.logger.enabled = true
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.logger
--    ...
--    logger is available

-- Internationalization
-- ====================
Platform:register ("i18n", function ()
  Platform.i18n = require "i18n"
  Platform.i18n.load {
    en = require "cosy.i18n.en",
  }
  getmetatable (Platform.i18n).__call = function (i18n, x)
    for k, v in pairs (x) do
      if type (v) == "table" and not getmetatable (v) then
        v.locale = x.locale
        x [k]    = i18n (v)
      end
    end
    return i18n.translate (x._, x)
  end
  local lfs = require "lfs"
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
              _      = "platform:available-locale",
              loaded = name,
            }
          end
        end
      end
    end
  end
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.i18n
--    ...
--    i18n is available

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
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.unique
--    ...
--    unique is available

-- Table dump
-- ==========
Platform:register ("table", function ()
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
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.table
--    ...
--    table is available

-- JSON
-- ====
Platform:register ("json", function ()
  Platform.json = require "cjson" .new ()
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.json
--    ...
--    json is available

-- YAML
-- ====
Platform:register ("yaml", function ()
  local yaml = require "yaml"
  Platform.yaml = {
    encode = yaml.dump,
    decode = yaml.load,
  }
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.yaml
--    ...
--    yaml is available

-- Compression
-- ===========
Platform:register ("compression", function ()
  Platform.compression.available = {}
  do
    Platform.compression.available.id = {
      compress   = function (x) return x end,
      decompress = function (x) return x end,
    }
  end
  Platform.compression.available.snappy = require "snappy"
  function Platform.compression.format (x)
    return x:match "^(%w+):"
  end
  function Platform.compression.compress (x, format)
    return format .. ":" .. Platform.Compressions [format].compress (x)
  end
  function Platform.compression.decompress (x)
    local format      = Platform.compression.format (x)
    local compression = Platform.compression.available [format]
    return  compression
       and  compression.decompress (x:sub (#format+2))
        or  error {
              _      = "compression:missing-format",
              format = format,
            }
  end
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.compression
--    ...
--    compression is available

-- Time
-- ====
Platform:register ("time", function ()
  local socket  = require "socket"
  Platform.time = socket.gettime
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.time
--    ...
--    time is available

-- Password Hashing
-- ================
Platform:register ("password", function ()
  local Configuration = require "cosy.configuration" .whole
  local bcrypt        = require "bcrypt"
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
  Platform.logger.debug {
    _     = "platform:bcrypt-rounds",
    count = Platform.password.rounds,
    time  = Configuration.data.password.time._ * 1000,
  }
end)
--    > Platform      = require "cosy.platform.standalone"
--    > Configuration = require "cosy.configuration" .whole
--    > Configuration.data.password.time = 0.001 -- second
--    > local _ = Platform.password
--    ...
--    using ... rounds in bcrypt for at least ... milliseconds of computation
--    password is available

-- MD5
-- ===
Platform:register ("digest", function ()
  Platform.md5 = require "md5"
  Platform.md5.digest = Platform.md5.sumhexa
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.digest
--    ...
--    digest is available

-- Redis
-- =====
Platform:register ("redis", function ()
  if _G.__TEST__ then
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
  else
    Platform.redis = require "redis"
  end
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.redis
--    ...
--    redis is available

-- Random
-- ======
Platform:register ("random", function ()
  math.randomseed (Platform.time ())
  Platform.random = math.random
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.random
--    ...
--    random is available

-- Token
-- =====
Platform:register ("token", function ()
  local jwt           = require "luajwt"
  local Configuration = require "cosy.configuration" .whole
  local Internal      = require "cosy.configuration" .internal
  if Configuration.token.secret._ == nil then
    error {
      _ = "platform:no-token-secret",
    }
  end
  Internal.token.algorithm._ = "HS512"
  Internal.token.validity._ = 600 -- seconds
  Platform.token = {}
  function Platform.token.encode (contents)
    local token = {}
    token.iat = Platform.time ()
    token.nbf = token.iat - 1
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
      error (err:match "^.*:%s*(.*)$")
    end
    return result
  end
  function Platform.token.decode (s)
    local key       = Configuration.token.secret._
    local algorithm = Configuration.token.algorithm._
    local result, err = jwt.decode (s, key, algorithm)
    if not result then
      error (errerr:match "^.*:%s*(.*)$")
    end
    return result.contents
  end
end)
--    > Platform      = require "cosy.platform.standalone"
--    > Configuration = require "cosy.configuration" .whole
--    > Configuration.token.secret = "secret"
--    > local _ = Platform.token
--    ...
--    token is available

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
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.configuration
--    ...
--    configuration is available

-- Scheduler
-- =========
Platform:register ("scheduler", function ()
  Platform.scheduler = require "cosy.scheduler" .create ()
end)

-- Email
-- =====
Platform:register ("email", function ()
  if _G.__TEST__ then
    Platform.email = {}
    Platform.email.send = function (t)
      Platform.email.last_sent = t
    end
  else
    local Email = require "cosy.email"
    Platform.email.send = Email.send
    if not Email.discover () then
      Platform.logger.warning {
        _ = "platform:no-smtp",
      }
    else
      local Configuration = require "cosy.configuration" .whole
      Platform.logger.debug {
        _        = "platform:smtp",
        host     = Configuration.smtp.host._,
        port     = Configuration.smtp.port._,
        method   = Configuration.smtp.method._,
        protocol = Configuration.smtp.protocol._,
      }
    end
  end
end)
--    > Platform = require "cosy.platform.standalone"
--    > local _ = Platform.email
--    ...
--    email is available

return Platform