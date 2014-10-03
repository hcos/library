local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local Data       = require "cosy.data"
local Tag        = require "cosy.tag"

local INSTANCE    = Tag.INSTANCE
local POSITION    = Tag.POSITION
local SELECTED    = Tag.SELECTED
local HIGHLIGHTED = Tag.HIGHLIGHTED

local global = _ENV or _G
local meta   = global.meta
local cosy   = global.cosy

local Helper = {}

function Helper.configure_editor (url)
  meta.editor = url
end

function Helper.configure_server (url, data)
  -- Remove trailing slash:
  if url [#url] == "/" then
    url = url:sub (1, #url-1)
  end
  -- Store:
  meta.servers [url] = {
    username = data.username,
    password = data.password,
  }
end

function Helper.resource (url)
  return cosy [url]
end

function Helper.id (x)
  assert (Data.is (x))
  while true do
    local y = Data.dereference (x)
    if not Data.is (y) then
      return tostring (x)
    end
    x = y
  end
end

function Helper.model (url)
  return cosy [url]
end

function Helper.instantiate (model, target_type, data)
  assert (Data.is (target_type))
  model [#model + 1] = target_type * {
    [INSTANCE] = true,
  }
  local result = model [#model]
  for k, v in pairs (data) do
    result [k] = v
  end
  return result
end

function Helper.create (model, source, link_type, target_type, data)
  ignore (link_type, target_type)
  local place_type      = model.place_type
  local transition_type = model.transition_type
  local arc_type        = model.arc_type
  local target
  if Helper.is_place (source) then
    model [#model + 1] = transition_type * {}
    target = model [#model]
  elseif Helper.is_transition (source) then
    model [#model + 1] = place_type * {}
    target = model [#model]
  else
    return
  end
  for k, v in pairs (data) do
    target [k] = v
  end
  model [#model + 1] = arc_type * {
    source = source,
    target = target,
  }
  return target
end

function Helper.remove (target)
  local model           = target / 2
  if Helper.is_place (target)
  or Helper.is_transition (target) then
    for _, x in pairs (model) do
      if Data.dereference (x.source) == target
      or Data.dereference (x.target) == target then
        Data.clear (x)
      end
    end
    Data.clear (target)
  elseif Helper.is_arc (target) then
    Data.clear (target)
  end
end

function Helper.types (model)
  return {
    place_type      = model.place_type,
    transition_type = model.transition_type,
    arc_type        = model.arc_type,
  }
end

function Helper.is (x, y)
  return Data.value (x [tostring (y)])
end

function Helper.is_place (x)
  return Helper.is (x, (x / 2).place_type)
end

function Helper.is_transition (x)
  return Helper.is (x, (x / 2).transition_type)
end

function Helper.is_arc (x)
  return Helper.is (x, (x / 2).arc_type)
end

function Helper.get_name (x)
  return Data.value (x.name)
end

function Helper.set_name (x, value)
  x.name = value
end

function Helper.get_token (x)
  return Data.value (x.token)
end

function Helper.set_token (x, value)
  x.token = value
end

function Helper.get_position (x)
  return Data.value (x [POSITION])
end

function Helper.set_position (x, value)
  x [POSITION] = value
end

function Helper.is_selected (x)
  return Data.value (x [SELECTED]) -- FIXME
end

function Helper.select (x)
  x [SELECTED] = true
end

function Helper.deselect (x)
  x [SELECTED] = nil
end

function Helper.is_highlighted (x)
  return Data.value (x [HIGHLIGHTED]) -- FIXME
end

function Helper.highlight (x)
  x [HIGHLIGHTED] = true
end

function Helper.unhighlight (x)
  x [HIGHLIGHTED] = nil
end

function Helper.source (x)
  return x.source
end

function Helper.target (x)
  return x.target
end

return Helper
