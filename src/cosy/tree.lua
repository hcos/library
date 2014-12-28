local Data     = require "cosy.data"
local Patches  = require "cosy.patches"
local Protocol = require "cosy.protocol"
local ignore   = require "cosy.util.ignore"

local NAME = Data.tags.NAME

local root_mt = {}

local Tree = {
  meta = {
    servers = {},
    models  = {},
  },
  store = Data.new {
    [NAME] = "root"
  },
  root = setmetatable ({}, root_mt)
}

function root_mt:__index (url)
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
  local root  = Tree.root
  local store = Tree.store
  local meta  = Tree.meta
  local model = rawget (store, url)
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
  assert (server)
  local metam = {
    model       = model,
    server      = server,
    resource    = url,
    patches     = Patches.new (),
    disconnect  = function ()
      Data.clear (model)
      meta.models [url] = nil
    end,
  }
  metam.protocol = Protocol.new (metam)
  metam.platform = Tree.Platform.new (metam)
  meta.models [url] = metam
  rawset (root, url, model)
  return model
end

function root_mt:__newindex ()
  ignore (self)
  assert (false)
end

return Tree
