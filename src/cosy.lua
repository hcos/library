local Tag      = require "cosy.tag"
local Data     = require "cosy.data"
local Protocol = require "cosy.protocol"
local Patches  = require "cosy.patches"
local ignore   = require "cosy.util.ignore"

local NAME     = Tag.NAME
local META     = Tag.new "META"
local INHERITS = Tag.new INHERITS

local Cosy = {}

local meta = Data.new {
  [NAME] = "meta"
}
local store = Data.new {
  [NAME] = "cosy"
}

-- Set global:
local global = _ENV or _G
global.cosy = setmetatable ({}, Cosy)
global.meta = meta
local cosy  = global.cosy

-- Load interface:
local Platform
if global.js then
  Platform = require "cosy.platform.js"
  Platform:log "Using JavaScript"
else
  Platform = require "cosy.platform.dummy"
  Platform:log "Using dummy"
end

local on_write_enabled = true

function Cosy:__index (url)
  ignore (self)
  if type (url) ~= "string" then
    return nil
  end
  -- FIXME: validate url
  -- If url does not use SSL, force it:
  if url:find "http://" == 1 then
    url = url:gsub ("^http://", "https://")
  end
  -- Remove trailing slash:
  if url [#url] == "/" then
    url = url:sub (1, #url-1)
  end
  --
  local model = rawget (cosy, url)
  if model ~= nil then
    return model
  end
  on_write_enabled = false
  model = store [url]
  --
  for k, server in pairs (meta.servers) do
    if url:sub (1, #k) == k then
      meta.models [url] = server {}
      break
    end
  end
  local meta = meta.models [url]
  meta.model       = model
  meta.resource    = url
  meta.editor.url  = url .. "/editor"
  meta.protocol    = Protocol.new (meta)
  meta.platform    = Platform.new (meta)
  meta.patch       = {
    action = "add-patch",
    token  = meta.editor.token,
  }
  meta.patches     = Patches.new ()
  meta.disconnect  = function ()
    Data.clear (model)
    Data.clear (meta)
  end
  rawset (cosy, url, model)
  on_write_enabled = true
  return model
end

function Cosy:__newindex ()
  ignore (self)
  assert (false)
end

Data.on_write.from_user = function (target, value, reverse)
  if not (store <= target) then
    return
  end
  local path     = Data.path (target)
  local url      = path [2]
  local meta     = meta.models [url]
  local protocol = meta.protocol ()
--  local patches  = meta.patches ()
  -- TODO: generate patch
--  patches:insert (meta.patch * {
--    code    = [[ ]] % { },
--    status  = "applied",
--    target  = target,
--    value   = value,
--    reverse = reverse,
--  })
  protocol:on_change ()
end

return {
  Cosy = Cosy,
  cosy = global.cosy,
  meta = meta,
}

-- Each data can have:
-- [TYPE] = "type" or "instance"
-- [INHERITS] = { string = true }
