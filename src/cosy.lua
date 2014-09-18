local Tag    = require "cosy.tag"
local Data   = require "cosy.data"
local ignore = require "cosy.util.ignore"
local http   = require "cosy.util.http"
local base64 = require "cosy.util.base64"
local dump   = require "cosy.dump"
local json   = require "dkjson"

local Cosy = {
  username = "",
  password = "",
  root_directory = os.getenv "HOME" .. "/.cosy/",
}

local NAME = Tag.NAME
local cosy = setmetatable ({
  [NAME] = "cosy"
}, Cosy)

local tokens = {}

function Cosy:configure (t)
  self.username = t.username
  self.password = t.password
  self.root_directory = t.root_directory
end

function Cosy:__index (url)
  if type (url) ~= "string" then
    return nil
  end
  -- FIXME: validate url
  print ("Loading " .. tostring (url))
  local resource = rawget (cosy, url)
  if resource then
    return Data.new (resource)
  end
  -- Step 1: ask for edition URL
  local headers
  if Cosy.username and Cosy.password then
    headers = {
      Authorization = base64 (Cosy.username .. ":" .. Cosy.password)
    }
  end
  local answer, status = http.request {
    url     = url,
    headers = headers,
  }
  -- create and load resource:
  rawset (cosy, url, {
    [NAME] = "model"
  })
  local model = Data.new (cosy) [url]
  if answer and status == 200 then
    answer = json.decode (answer)
    tokens [url] = answer.token
    self:open_connection (answer.editor)
  else
    -- load from file
    assert (Cosy.root_directory)
    local lfs = require "lfs"
    if not lfs.attributes (Cosy.root_directory) then
      assert (lfs.mkdir (Cosy.root_directory))
    end
    local filename = Cosy.root_directory ..
                     url:gsub ("^https?://", ""):gsub ("/", "-")
    if not lfs.attributes (filename) then
      local file = io.open (filename, "w")
      file:write ("local model = " .. tostring (model) .. "\n")
      file:close ()
    end
    local loader = loadfile (filename)
    assert (loader)
    loader ()
    local file = io.open (filename, "a+")
    -- set handler to write changed on file
    Data.on_write [Cosy] = function (target, value)
      if model < target then
        local patch = tostring (target % model) .. " = " .. dump (value) .. "\n"
        file:write (patch)
        file:flush ()
      end
    end
  end
  return model
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

-- Set global:
local global = _ENV or _G
global.cosy = cosy
global.Cosy = Cosy

-- Load interface:
if global.js then
  require "cosy.interface.js"
--elseif then
--  require "cosy.interface.socket"
else
--  require "cosy.interface.dummy"
end

return global.cosy
