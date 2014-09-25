local Tag      = require "cosy.tag"
local Data     = require "cosy.data"
local Protocol = require "cosy.protocol"
local ignore   = require "cosy.util.ignore"

local NAME = Tag.NAME

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

-- Load interface:
local Platform
if global.js then
  Platform = require "cosy.platform.js"
  Platform:log "Using JavaScript"
else
--  Platform = require "cosy.interface.c"
end

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
  local resource = rawget (store, url)
  if resource then
    return resource
  end
  local model = store [url]
  --
  for k, server in pairs (meta.servers) do
    if url:sub (1, #k) == k then
      meta.models [model] = server {}
      break
    end
  end
  local meta = meta.models [model]
  meta.model       = model
  meta.resource    = url
  meta.editor.url  = url .. "/editor"
  meta.protocol    = Protocol.new (meta)
  meta.platform    = Platform.new (meta)
  meta.patch       = {
    action = "add-patch",
    token  = meta.editor.token,
  }
  meta.patches     = {}
  meta.patches.ids = {}
  meta.disconnect  = function ()
    Data.clear (model)
    Data.clear (meta)
  end
  store [url] = model
  return model
end

function Cosy:__newindex ()
  ignore (self)
  assert (false)
end


Data.on_write.from_user = function (target, value, reverse)
  if target / 1 ~= store then
    return
  end
  local model    = target / 2
  local meta     = meta.models [model]
  local protocol = meta.protocol ()
  -- TODO: generate patch
  meta.patches [#(meta.patches) + 1] = meta.patch * {
    code    = [[ ]] % { },
    id      = # (meta.patches.ids) + 1,
    status  = "applied",
    target  = target,
    value   = value,
    reverse = reverse,
  }
  meta.patches.ids [#(meta.patches.ids) + 1] = true
  protocol:on_change ()
end

return {
  Cosy = Cosy,
  cosy = global.cosy,
  meta = meta,
}
