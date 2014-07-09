require "cosy.connexion.js"

local tags = require "cosy.lang.tags"
local seq  = require "cosy.lang.iterators" . seq
local map  = require "cosy.lang.iterators" . map

local TYPE = tags.TYPE
TYPE.persistent = true

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
  do
    p = {}
    p [TYPE] = model.types.place
    p.name = 'r_0'
    p.marking = 1
    p.x = 100
    p.y = 100
    p.highlighted = false
    model['r_0'] = p
    print "Remove p_0"
    model['r_0'] = nil
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
