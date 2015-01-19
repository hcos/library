local _      = require "cosy.util.string"
local ignore = require "cosy.util.ignore"

local global = _ENV or _G

local Platform = {}

-- Logger
-- ======
Platform.logger = {}
if pcall (function ()
  local logging   = require "logging"
  logging.console = require "logging.console"
  local backend   = logging.console "%level %message\n"
  function Platform.logger:debug (message)
    if self.enabled then
      backend:debug (message)
    end
  end
  function Platform.logger:info (message)
    if self.enabled then
      backend:info (message)
    end
  end
  function Platform.logger:warning (message)
    if self.enabled then
      backend:warn (message)
    end
  end
  function Platform.logger:error (message)
    if self.enabled then
      backend:error (message)
    end
  end
end) then
  Platform.logger.enabled = true
  Platform.logger:debug "Logger is available through lualogging."
elseif pcall (function ()
  local backend = require "log".new ("debug",
    require "log.writer.console.color".new ()
  )
  function Platform.logger:debug (message)
    if self.enabled then
      backend.notice (message)
    end
  end
  function Platform.logger:info (message)
    if self.enabled then
      backend.info (message)
    end
  end
  function Platform.logger:warning (message)
    if self.enabled then
      backend.warning (message)
    end
  end
  function Platform.logger:error (message)
    if self.enabled then
      backend.error (message)
    end
  end
end) then
  Platform.logger.enabled = true
  Platform.logger:debug "Logger is available through lua-log."
else
  function Platform.logger:debug ()
  end
  function Platform.logger:info ()
  end
  function Platform.logger:warning ()
  end
  function Platform.logger:error ()
  end
end

-- Foreign Function Interface
-- ==========================
if global.jit then
  Platform.ffi = require "ffi"
  Platform.logger:debug "FFI is available through LuaJIT."
elseif pcall (function ()
  Platform.ffi = require "luaffi"
end) then
  Platform.logger:debug "FFI is available through luaffi."
else
  Platform.logger:debug "FFI is not available."
end

-- Unique ID generator
-- ===================
Platform.unique = {}
function Platform.unique.id ()
  error "Not implemented yet"
end
function Platform.unique.uuid ()
  local run    = io.popen ("uuidgen", "r")
  local result = run:read "*l"
  run:close ()
  return result
end

-- JSON
-- ====
if pcall (function ()
  Platform.json = require "cjson"
end) then
  Platform.logger:debug "JSON is available using cjson."
elseif pcall (function ()
  global.always_try_using_lpeg = true
  Platform.json = require "dkjson"
end) then
  Platform.logger:debug "JSON is available using dkjson and lpeg."
elseif pcall (function ()
  global.always_try_using_lpeg = false
  Platform.json = require "dkjson"
end) then
  Platform.logger:debug "JSON is available using dkjson."
else
  Platform.logger:error "JSON is not available."
  error "Missing dependency."
end

-- YAML
-- ====
if pcall (function ()
  local yaml = require "lyaml"
  Platform.yaml = {
    encode = yaml.dump,
    decode = yaml.load,
  }
end) then
  Platform.logger:debug "YAML is available using lyaml."
elseif pcall (function ()
  local yaml = require "yaml"
  Platform.yaml = {
    encode = yaml.dump,
    decode = yaml.load,
  }
end) then
  Platform.logger:debug "YAML is available using yaml."
elseif pcall (function ()
  local yaml = require "luayaml"
  Platform.yaml = {
    encode = yaml.dump,
    decode = yaml.load,
  }
end) then
  Platform.logger:debug "YAML is available using luayaml."
else
  Platform.logger:error "YAML is not available."
  error "Missing dependency."
end

-- Compression
-- ===========
Platform.compression = {}

Platform.compression.available = {}
do
  Platform.compression.available.id = {
    compress   = function (x) return x end,
    decompress = function (x) return x end,
  }
  Platform.logger:debug "Compression 'id' is available."
end
ignore (pcall (function ()
  Platform.compression.available.lz4 = require "lz4"
  Platform.logger:debug "Compression 'lz4' is available."
end))
ignore (pcall (function ()
  Platform.compression.available.snappy = require "snappy"
  Platform.logger:debug "Compression 'snappy' is available."
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
      or error ("Compression format '${format}' is not available" % {
        format = format,
      })
end

-- Configuration
-- =============
Platform.configuration = {}

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

-- Password Hashing
-- ================
Platform.password = {}
Platform.password.computation_time = 0.010 -- milliseconds
if pcall (function ()
  local bcrypt = require "bcrypt"
  local socket = require "socket"
  local function compute_rounds ()
    for _ = 1, 5 do
      local rounds = 5
      while true do
        local start = socket.gettime ()
        bcrypt.digest ("some random string", rounds)
        local delta = socket.gettime () - start
        if delta > Platform.password.computation_time then
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
  Platform.logger:debug "Password hashing using 'bcrypt' is available:"
  Platform.logger:debug ("  - using ${rounds} rounds for at least ${time} milliseconds" % {
    rounds = Platform.password.rounds,
    time   = Platform.password.computation_time * 1000,
  })
else
  Platform.logger:error "Password hashing is not available."
  error "Missing dependency."
end

return Platform