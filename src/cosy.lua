local Tag    = require "cosy.tag"
local Data   = require "cosy.data"
local ignore = require "cosy.util.ignore"

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

function Cosy:configure (t)
  self.username = t.username
  self.password = t.password
  self.root_directory = t.root_directory
end

function Cosy:__index (url)
  ignore (self)
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
  local model = Data.new (cosy) [url]
  -- Step 1: ask for edition URL
  local headers
  if Cosy.username and Cosy.password then
    headers = {
      Authorization = base64.encode (Cosy.username .. ":" .. Cosy.password)
    }
  end
  do
    local answer, status = interface.request {
      url     = url .. "/editor",
      headers = headers,
    }
    -- Try websocket:
    if answer and status == 200 then
      answer = json.decode (answer)
      if pcall (function () interface.dynamic (url, answer) end) then
        return model
      end
    end
  end
  -- Try to download model:
  do
    local answer, status = interface.request {
      url     = url,
      headers = headers,
    }
    if answer and status == 200 then
      if pcall (function () interface.static (url, answer) end) then
        return model
      end
    end
  end
  -- Try filesystem:
  do
    if pcall (function () interface.filesystem (url) end) then
      return model
    end
  end
  -- Error:
  assert (false)
end

function Cosy:__newindex ()
  ignore (self)
  assert (false)
end

return global.cosy
