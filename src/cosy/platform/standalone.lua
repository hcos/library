local _      = require "cosy.util.string"
local ignore = require "cosy.util.ignore"

local global = _ENV or _G

local Platform = {}

-- Logger
-- ======
local logging    = require "logging"
logging.console   = require "logging.console"
Platform.logger = logging.console "%level %message\n"

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
  format = format or Platform.Compressions.default
  return format .. ":" .. Platform.Compressions[format].compress (x)
end
function Platform.compression.decompress (x)
  local format = Platform.compression.format (x)
  local Compression = Platform.Compressions[format]
  return Compression
     and Compression.decompress (x:sub (#format+2))
      or error "Compression not found"
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

return Platform