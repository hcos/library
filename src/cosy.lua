local Tag      = require "cosy.tag"
local Data     = require "cosy.data"
local Patches  = require "cosy.patches"
local Protocol = require "cosy.protocol"
local ignore   = require "cosy.util.ignore"

local NAME = Tag.NAME

local Cosy = {}

local meta = {
  servers = {},
  models  = {},
}
local store = Data.new {
  [NAME] = "cosy"
}

-- Set global:
local global = _ENV or _G
global.cosy = setmetatable ({}, Cosy)
global.meta = meta
global.Tag  = Tag
local cosy  = global.cosy

-- Load interface:
local Platform
if global.js then
  Platform = require "cosy.platform.js"
  Platform:log "Using JavaScript"
elseif global.ev then
  Platform = require "cosy.platform.ev"
  Platform:log "Using ev"
else
  Platform = require "cosy.platform.dummy"
  Platform:log "Using dummy"
end

function Cosy:__index (url)
  ignore (self)
  if type (url) ~= "string" then
    return nil
  end
  -- FIXME: validate url
  -- Remove trailing slash:
  if url [#url] == "/" then
    url = url:sub (1, #url-1)
  end
  --
  local model = rawget (cosy, url)
  if model ~= nil then
    return model
  end
  model = store [url]
  --
  local server
  for k, v in pairs (meta.servers) do
    if url:find ("^" .. k) == 1 then
      server = v
      break
    end
  end
  local metam = {
    model       = model,
    server      = server,
    resource    = url,
    editor      = meta.editor,
    patches     = Patches.new (),
    disconnect  = function ()
      Data.clear (model)
      meta.models [url] = nil
    end,
  }
  metam.protocol = Protocol.new (metam)
  metam.platform = Platform.new (metam)
  meta.models [url] = metam
  rawset (cosy, url, model)
  return model
end

function Cosy:__newindex ()
  ignore (self)
  assert (false)
end

local Module = {}

Module.cosy  = cosy

Module.meta  = meta

function Module.start ()
  Platform.start ()
end

function Module.respond ()
  Platform.respond ()
end

function Module.stop ()
  Platform.stop ()
end

return Module
