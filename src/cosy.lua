cosy = require "cosy.lang.cosy"
window.cosy = cosy

local observed = require "cosy.lang.view.observed"

observed [#observed + 1] = require "cosy.lang.view.update"
cosy = observed (cosy)

local tags = require "cosy.lang.tags"
local raw  = require "cosy.lang.data" . raw
local seq  = require "cosy.lang.iterators" . seq
local map  = require "cosy.lang.iterators" . map

local TYPE = tags.TYPE
TYPE.persistent = true

function window:count (x)
  return #x
end

function window:id (x)
  if type (x) == "table" then
    local mt = getmetatable (x)
    setmetatable (x, nil)
    local result = tostring (x)
    setmetatable (x, mt)
    return result
  else
    return tostring (x)
  end
end

function window:keys (x)
  local result = {}
  for key, _ in pairs (x) do
    result [#result + 1] = key
  end
  return result
end

function window:elements (model)
  local result = {}
  for _, x in map (model) do
    if type (x) . table and x [TYPE] then
      result [#result + 1] = x
    elseif type (x) . table then
      for y in seq (window:elements (x)) do
        result [#result + 1] = y
      end
    end
  end
  return result
end

function window:connect (editor, token, resource)
  local connect = require "cosy.connexion.js"
  return connect {
    editor   = editor,
    token    = token,
    resource = resource,
  }
end



function window:do_something (model)
  model.types = {
    place       = {},
    transition  = {},
    arc         = {},
  }
  do
    p = {}
    p [TYPE] = model.types.place
    p.name = 'p_0'
    p.marking = 1
    p.x = 100
    p.y = 100
    p.highlighted = true
    model['p_0'] = p
  end
  do
    p = {}
    p [TYPE] = model.types.place
    p.name = 'p_1'
    p.marking = 1
    p.x = 800 
    p.y = 100
    model['p_1'] = p
  end
  do
    t = {}
    t [TYPE] = model.types.transition
    t.name = 't_0_1'
    t.x = 480 
    t.y = 250
    model['t_0_1'] = t
  end
  do
    a = {}
    a [TYPE] = model.types.arc
    a.source = model['p_0']
    a.target = model['t_0_1']
    a.valuation = 1
    model[#model + 1] = a
  end
  do
    a = {}
    a [TYPE] = model.types.arc
    a.source = model['t_0_1']
    a.target = model['p_1']
    a.valuation = 1
    model[#model + 1] = a
  end
  local keys = {};
  for k in map (model) do 
      keys[#keys+1] = k; 
  end
  --[[
  --local window    = js.global; 
  --window.model    = observed (model);
  --window.keys     = keys; 
  --window.count    = #keys; 
  --window.var_type = type; 
  --window.type_place      = place; 
  --window.type_transition = transition; 
  --window.type_arc        = arc;
  --]]
  local show = function ()
    local updates = model [tags.UPDATES];
    print (updates)
    for s in seq (updates) do
      print (s.patch)
    end
  end
  -- show ()
end
