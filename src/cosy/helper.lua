local _        = require "cosy.util.string"
local Tree     = require "cosy.tree"
local Data     = require "cosy.data"

local HIDDEN      = "cosy:hidden"
local HIGHLIGHTED = "cosy:highlighted"
local INSTANCE    = "cosy:instance"
local POSITION    = "cosy:position"
local SELECTED    = "cosy:selected"
local TYPE        = "cosy:type"

local Helper_mt = {}
local Helper = setmetatable ({}, Helper_mt)

function Helper.configure_platform (platform)
  Tree.Platform = platform
  Helper.configure_platform = nil
end

function Helper.configure_server (base, data)
  assert (data.www)
  Tree.meta.servers [base] = {
    www       = data.www,
    rest      = data.rest,
    websocket = data.websocket,
    username  = data.username,
    password  = data.password,
  }
end

function Helper.on_write (k, f)
  Data.on_write [k] = f
end

function Helper.resource (url)
  return Tree.root [url]
end

function Helper.id (x)
  assert (Data.is (x), "Parameter is not a data.")
  while true do
    local y = Data.dereference (x)
    if not Data.is (y) then
      return tostring (x)
    end
    x = y
  end
end

function Helper.new_type (parent, data)
  local result
  if parent then
    result = parent * {
      [TYPE  ] = true,
      [HIDDEN] = false,
    }
  else
    result = {
      [TYPE] = true,
    }
  end
  for k, v in pairs (data or {}) do
    result [k] = v
  end
  return result
end

function Helper.new_instance (parent, data)
  assert (Helper.is_type (parent) and Helper.is_visible (parent))
  local result = parent * {
    [INSTANCE] = true,
    [TYPE    ] = false,
    [HIDDEN  ] = false,
  }
  for k, v in pairs (data or {}) do
    result [k] = v
  end
  return result
end

function Helper.insert (model, target)
  model [#model + 1] = target
  return model [#model]
end

function Helper.remove (target)
  local model = target / 2
  if Helper.is_vertex (target) then
    for _, x in pairs (model) do
      if Helper.source (x) == target
      or Helper.target (x) == target then
        Data.clear (x)
      end
    end
    Data.clear (target)
  elseif Helper.is_link (target) then
    Data.clear (target)
  end
end

function Helper.types (model)
  local result = {}
  for k, x in pairs (model) do
    if x [TYPE] () and not x [HIDDEN] () then
      result [k] = x
      print (tostring (k) .. " => " .. tostring (x))
    end
  end
  return result
end

function Helper.is (x, y)
  return y <= x
end

function Helper.hide (x)
  x [HIDDEN] = true
end

function Helper.is_empty (x)
  return Data.exists (x)
end

function Helper.is_hidden (x)
  return x [HIDDEN] ()
end

function Helper.is_visible (x)
  return not x [HIDDEN] ()
end

function Helper.is_type (x)
  return x [TYPE] ()
end

function Helper.is_instance (x)
  return x [INSTANCE] ()
end

function Helper.get_name (x)
  local result = Data.value (x.name)
  if type (result) == "function" then
    result = result (x)
  end
  return result
end

function Helper.set_name (x, value)
  x.name = value
end

function Helper.get_token (x)
  local result = Data.value (x.token)
  if type (result) == "function" then
    result = result (x)
  end
  return result
end

function Helper.set_token (x, value)
  x.token = value
end

function Helper.get_position (x)
  local result = Data.value (x [POSITION])
  if type (result) == "function" then
    result = result (x)
  end
  return result
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
  return Data.dereference (x.source)
end

function Helper.target (x)
  return Data.dereference (x.target)
end

return Helper
