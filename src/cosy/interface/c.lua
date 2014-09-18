local logging   = require "logging"
logging.console = require "logging.console"
local logger    = logging.console "%level %message\n"

local global = _ENV or _G

local result = {}

function result.request (x, y)
  local http  = require "socket.http"
  local https = require "ssl.https"
  local implementation
  if type (x) == "string" then
    if x:find "http://" == 1 then
      implementation = http
    elseif x:find "https://" == 1 then
      implementation = https
    end
  elseif type (x) == "table" then
    if x.url:find "http://" == 1 then
      implementation = http
    elseif x.url:find "https://" == 1 then
      implementation = https
    end
  end
  return implementation.request (x, y)
end

function result.dynamic ()
  -- open websocket connection
  -- set resource
  -- fetch model
  -- store as remote
  -- send local changes
  -- remove local changes
  -- set handlers
  assert (false)
end

function result.static (url, data)
  logger:debug ("Loading ${url} from static remote." % { url = url })
  local Data   = require "cosy.data"
  local dump   = require "cosy.dump"
  local base64 = require "ee5_base64"
  local Cosy = global.Cosy
  local cosy = global.cosy
  local model = Data.new (cosy) [url]
  if not pcall (function ()
    logger:debug ("Trying to also use filesystem.")
    local lfs = require "lfs"
    assert (Cosy.root_directory)
    -- Create root directory if it does not exist:
    if not lfs.attributes (Cosy.root_directory) then
      assert (lfs.mkdir (Cosy.root_directory))
    end
    local base_file   = Cosy.root_directory .. base64.encode (url)
    local remote_file = base_file .. ".remote.cosy"
    local local_file  = base_file .. ".local.cosy"
    -- Replace remote file:
    do
      local file = io.open (remote_file, "w")
      file:write (data)
      file:close ()
    end
    -- Create local file if it does not exist:
    if not lfs.attributes (local_file) then
      local file = io.open (local_file, "w")
      file:write ("local model = " .. tostring (model) .. "\n")
      file:close ()
    end
    -- Load remote and local files:
    for _, filename in ipairs { remote_file, local_file } do
      local loader = loadfile (filename)
      assert (loader)
      loader ()
    end
    -- Set handler to write changes in local file:
    local file = io.open (local_file, "a+")
    Data.on_write [Cosy] = function (target, value)
      if model < target then
        local patch = tostring (target % model) ..
                      " = " .. dump (value) .. "\n"
        file:write (patch)
        file:flush ()
      end
    end
  end) then
    logger:warn ("Filesystem unusable.")
    local loader = loadstring (data)
    assert (loader)
    loader ()
  end
  return true
end

function result.filesystem (url)
  logger:debug ("Loading ${url} from filesystem." % { url = url })
  local Data   = require "cosy.data"
  local dump   = require "cosy.dump"
  local base64 = require "ee5_base64"
  local lfs    = require "lfs"
  local Cosy = global.Cosy
  local cosy = global.cosy
  local model = Data.new (cosy) [url]
  assert (Cosy.root_directory)
  -- Create root directory if it does not exist:
  if not lfs.attributes (Cosy.root_directory) then
    assert (lfs.mkdir (Cosy.root_directory))
  end
  local base_file   = Cosy.root_directory .. base64.encode (url)
  local remote_file = base_file .. ".remote.cosy"
  local local_file  = base_file .. ".local.cosy"
  -- Create file if it does not exist:
  for _, filename in ipairs { remote_file, local_file } do
    if not lfs.attributes (filename) then
      local file = io.open (filename, "w")
      file:write ("local model = " .. tostring (model) .. "\n")
      file:close ()
    end
  end
  -- Load remote and local files:
  for _, filename in ipairs { remote_file, local_file } do
    local loader = loadfile (filename)
    assert (loader)
    loader ()
  end
  -- Set handler to write changes in local file:
  local file = io.open (local_file, "a+")
  Data.on_write [Cosy] = function (target, value)
    if model < target then
      local patch = tostring (target % model) ..
                    " = " .. dump (value) .. "\n"
      file:write (patch)
      file:flush ()
    end
  end
end

return result
