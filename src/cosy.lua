local Tag    = require "cosy.tag"
local Data   = require "cosy.data"
local ignore = require "cosy.util.ignore"
local dump   = require "cosy.dump"

local json   = require "dkjson"
local base64 = require "ee5_base64"

local Cosy = {
  username = nil,
  password = nil,
  root_directory = os.getenv "HOME" .. "/.cosy/",
}

local NAME = Tag.NAME
local cosy = setmetatable ({
  [NAME] = "cosy"
}, Cosy)

-- Set global:
local global = _ENV or _G
global.cosy = cosy
global.Cosy = Cosy

-- Load interface:
local interface
if global.js then
  interface = require "cosy.interface.js"
else
  interface = require "cosy.interface.c"
end

local tokens = {}

function Cosy:configure (t)
  self.username = t.username
  self.password = t.password
  self.root_directory = t.root_directory
end

local function from_server (url)
  -- TODO
end

local function from_file (url)
  local model = Data.new (cosy) [url]
  assert (Cosy.root_directory)
  local lfs = require "lfs"
  -- Create root directory if it does not exist:
  if not lfs.attributes (Cosy.root_directory) then
    assert (lfs.mkdir (Cosy.root_directory))
  end
  local filename = Cosy.root_directory .. base64.encode (url)
  -- Create file if it does not exist:
  if not lfs.attributes (filename) then
    local file = io.open (filename, "w")
    file:write ("local model = " .. tostring (model) .. "\n")
    file:close ()
  end
  -- Load file:
  local loader = loadfile (filename)
  assert (loader)
  loader ()
  -- Set handler to write changed on file
  local file = io.open (filename, "a+")
  Data.on_write [Cosy] = function (target, value)
    if model < target then
      local patch = tostring (target % model) .. " = " .. dump (value) .. "\n"
      file:write (patch)
      file:flush ()
    end
  end
  return model
end

function Cosy:__index (url)
  if type (url) ~= "string" then
    return nil
  end
  -- If url does not use SSL, force it:
  if url:find "http://" == 1 then
    url = url:gsub ("^http://", "https://")
  end
  -- FIXME: validate url
  print ("Loading " .. tostring (url))
  local resource = rawget (cosy, url)
  if resource then
    return Data.new (resource)
  end
  -- create and load resource:
  rawset (cosy, url, {
    [NAME] = "model"
  })
  --
  if interface.request then
    -- ...
  end
  -- Step 1: ask for edition URL
  local headers
  if Cosy.username and Cosy.password then
    headers = {
      Authorization = base64.encode (Cosy.username .. ":" .. Cosy.password)
    }
  end
  local answer, status = interface.request {
    url     = url,
    headers = headers,
  }
  if answer and status == 200 then
    -- connect to websocket
    answer = json.decode (answer)
    tokens [url] = answer.token
    -- open websocket connection
    -- set resource
    -- fetch model
    -- set handlers
  else
    return from_file (url)
  end
end

function Cosy:__newindex ()
  ignore (self)
  assert (false)
end

function Cosy:on_connect ()
end

function Cosy:on_disconnect ()
end

function Cosy:on_change ()
end

function Cosy:on_message ()
end

return global.cosy
