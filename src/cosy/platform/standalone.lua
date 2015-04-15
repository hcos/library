_G.coroutine = require "coroutine.make" ()

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

-- Internationalization
-- ====================
Platform:register ("i18n", function ()
  Platform.i18n = require "i18n"
  getmetatable (Platform.i18n).__call = function (i18n, x)
    local locale = x.locale or "en"
    if not package.loaded ["cosy.i18n." .. locale] then
      local ok, loaded = pcall (require, "cosy.i18n." .. locale)
      if ok then
        Platform.i18n.load {
          [locale] = loaded,
        }
        Platform.logger.info {
          _      = "platform:available-locale",
          loaded = locale,
        }
      end
    end
    for k, v in pairs (x) do
      if type (v) == "table" and not getmetatable (v) then
        v.locale = x.locale
        x [k]    = i18n (v)
      end
    end
    return i18n.translate (x._, x)
  end
end)

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

-- Value dump
-- ==========
Platform:register ("value", function ()
  local serpent = require "serpent"
  function Platform.value.encode (t, options)
    return serpent.dump (t, options or {
      sortkeys = false,
      compact  = true,
      fatal    = true,
      comment  = false,
    })
  end
  function Platform.value.expression (t, options)
    return serpent.line (t, options or {
      sortkeys = true,
      compact  = true,
      fatal    = true,
      comment  = false,
      nocode   = true,
    })
  end
  function Platform.value.decode (s)
    local ok, result = serpent.load (s, {
      safe = false,
    })
    if not ok then
      error (err)
    end
    return result
  end
end)

-- JSON
-- ====
Platform:register ("json", function ()
  Platform.json = require "cjson" .new ()
end)

-- YAML
-- ====
Platform:register ("yaml", function ()
  local yaml = require "yaml"
  Platform.yaml = {
    encode = yaml.dump,
    decode = yaml.load,
  }
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

-- Time
-- ====
Platform:register ("time", function ()
  local socket  = require "socket"
  Platform.time = socket.gettime
end)

-- Password Hashing
-- ================
Platform:register ("password", function ()
  local Configuration = require "cosy.configuration"
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

-- Digest
-- ======
Platform:register ("digest", function ()
  local Crypto = require "crypto"
  Platform.digest = function (s)
    return Crypto.hex (Crypto.digest ("SHA256", s))
  end
end)

-- Encrypt
-- =======
Platform:register ("encryption", function ()
  local Crypto = require "crypto"
  local Mime   = require "mime"
  Platform.encryption = {}
  Platform.encryption.encode = function (s, key)
    return Mime.b64 (Crypto.encrypt ("AES256", s, key))
  end
  Platform.encryption.decode = function (s, key)
    return Crypto.decrypt ("AES256", Mime.unb64 (s), key)
  end
end)

-- Redis
-- =====
Platform:register ("redis", function ()
  local Configuration = require "cosy.configuration"
  local scheduler     = Platform.scheduler
  local Redis         = require "redis"
  local assigned      = {}
  function Platform.redis ()
    local co    = coroutine.running ()
    local found = assigned [co]
    if found then
      return found
    end
    repeat
      local count = 0
      for other, client in pairs (assigned) do
        if coroutine.status (other) == "dead" then
          assigned [other] = nil
          if pcall (client.ping, client) then
            assigned [co] = client
            return client
          end
        else
          count = count+1
        end
      end
      if count < Configuration.redis.pool_size._ then
        local coroutine = require "coroutine.make" ()
        local host      = Configuration.redis.host._
        local port      = Configuration.redis.port._
        local database  = Configuration.redis.database._
        local socket    = Platform.socket.tcp ()
        socket:connect (host, port)
        local client = Redis.connect {
          socket    = socket,
          coroutine = coroutine,
        }
        client:select (database)
        assigned [co] = client
        return client
      else
        Platform.scheduler.sleep (0.01)
      end
    until false
  end
end)

-- Random
-- ======
Platform:register ("random", function ()
  math.randomseed (Platform.time ())
  Platform.random = math.random
end)

-- Token
-- =====
Platform:register ("token", function ()
  local jwt           = require "luajwt"
  local Configuration = require "cosy.configuration"
  if Configuration.token.secret._ == nil then
    error {
      _ = "platform:no-token-secret",
    }
  end
  Platform.token = {}
  function Platform.token.encode (token)
    local secret      = Configuration.token.secret._
    local algorithm   = Configuration.token.algorithm._
    local result, err = jwt.encode (token, secret, algorithm)
    if not result then
      error (err)
    end
    return result
  end
  function Platform.token.decode (s)
    local key         = Configuration.token.secret._
    local algorithm   = Configuration.token.algorithm._
    local result, err = jwt.decode (s, key, algorithm)
    if not result then
      error (err)
    end
    return result
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
  Platform.scheduler = require "copas.ev"
  Platform.scheduler:make_default ()
end)

-- Socket
-- ======
Platform:register ("socket", function ()
  local socket    = require "socket"
  Platform.socket = {}
  function Platform.socket.tcp ()
    local skt    = socket.tcp ()
    local result = Platform.scheduler.wrap (skt)
    return result
  end
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
      local Configuration = require "cosy.configuration"
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

Platform:register ("client", function ()
  Platform.client = function (url)
    local Configuration = require "cosy.configuration"
    local Methods       = require "cosy.methods"
    local Coevas        = require "copas.ev"
    Coevas:make_default ()
    local Websocket     = require "websocket"
    local ws = Websocket.client.copas {
      timeout = Configuration.client.timeout._,
    }
    ws:connect (url, "cosy")
    local waiting   = {}
    local results   = {}
    local running   = true
    Coevas.addthread (function ()
      while running do
        local message = ws:receive ()
        if not message then
          break
        end
        message = Platform.value.decode (message)
        local identifier = message.identifier
        results [identifier] = message
        local thread     = waiting [identifier]
        if thread then
          coroutine.wakeup (thread)
        end
      end
    end)
    local client = {}
    function client.loop ()
      Coevas.loop ()
    end
    function client.unloop ()
      Coevas.unloop ()
    end
    for operation in pairs (Methods) do
      client [operation] = function (parameters)
        local result = nil
        Coevas.addthread (function ()
          local identifier = #results+1
          waiting [identifier] = coroutine.running ()
          results [identifier] = nil
          ws:send {
            identifier = identifier,
            operation  = operation,
            parameters = parameters,
          }
          Coevas.sleep (Configuration.timeout._)
          result = results [identifier]
          waiting [identifier] = nil
          results [identifier] = nil
          Coevas.unloop ()
        end)
        Coevas.loop ()
        if result == nil then
          error {
            _ = "timeout",
          }
        elseif result.success then
          return result.response
        else
          error (result.response)
        end
      end
    end
    return client
  end
end)

return Platform