local Repository         = {}
Repository.__metatable   = "cosy.repository"
Repository.value         = "cosy:value"
Repository.proxy         = "cosy:proxy"
Repository.resource      = "cosy:resource"
Repository.depends       = "cosy:depends"
Repository.refers        = "cosy:refers"
Repository.refines       = "cosy:refines"
Repository.follow        = "cosy:follow"

local Resource           = {}
Resource.__metatable     = "cosy.resource"

local Proxy              = {}
Proxy.__metatable        = "cosy.resource.proxy"

local Cache              = {}
Cache.__metatable        = "cosy.resource.cache"
Cache.__mode             = "kv"

local IgnoreKeys         = {}
IgnoreKeys.__metatable   = "cosy.resource.ignorekeys"
IgnoreKeys.__mode        = "k"

local IgnoreValues       = {}
IgnoreValues.__metatable = "cosy.resource.ignorevalues"
IgnoreValues.__mode      = "v"

local function make_tag (name)
  return setmetatable ({}, {
    __tostring = function () return name end
  })
end

local CACHES     = make_tag "CACHES"
local CREATED    = make_tag "CREATED"
local DATA       = make_tag "DATA"
local OPTIONS    = make_tag "OPTIONS"
local PROXIES    = make_tag "PROXIES"
local FOLLOW     = make_tag "FOLLOW"
local KEYS       = make_tag "KEYS"
local NAME       = make_tag "NAME"
local PARENT     = make_tag "PARENT"
local REPOSITORY = make_tag "REPOSITORY"
local RESOURCES  = make_tag "RESOURCES"
local RESOURCE   = make_tag "RESOURCE"

-- Repository
-- ----------

function Repository.new ()
  local repository = {
    [CACHES    ] = {},
    [CREATED   ] = {},
    [OPTIONS   ] = {
      create = nil,
      import = nil,
    },
    [PROXIES   ] = setmetatable ({}, IgnoreValues),
    [RESOURCES ] = setmetatable ({}, IgnoreValues),
  }
  local placeholder = Proxy.new (setmetatable ({
    [NAME      ] = false,
    [REPOSITORY] = repository,
  }, Resource))
  repository [RESOURCES] [false] = placeholder
  repository [CREATED  ] [placeholder] = true
  return setmetatable (repository, Repository)
end

--    > Repository = require "cosy.resource"
--    > repository = Repository.new ()

function Repository.options (repository)
  return repository [OPTIONS]
end

--    > print (Repository.options (repository))

--    > Repository.options (repository).create = function () end
--    > Repository.options (repository).import = function ()
--    >   return { a = 1, b = 2 }
--    > end

function Repository.__index (repository, key)
  local found = repository [RESOURCES] [key]
  if found then
    repository [CREATED] [found] = nil
    return Proxy.new (found)
  end
  local import = repository [OPTIONS].import
  local data   = import (repository, key)
  return Resource.import (repository, key, data)
end

--    > resource = repository.myresource

function Repository.__newindex (repository, key, data)
  if data == nil then
    repository [RESOURCES] [key] = nil
    return
  end
  local create = repository [OPTIONS].create
  create (repository, key)
  Resource.import (repository, key, data)
end

function Repository.placeholder (repository)
  return repository [RESOURCES] [false]
end

function Repository.flatten ()
  error "Not implemented yet"
end

function Repository.export (proxy)
  proxy = Proxy.dereference (proxy)
  local loader      = require "cosy.loader"
  local resource    = proxy [RESOURCE]
  local mt          = Proxy.__metatable
  Proxy.__metatable = nil
  local result     = loader.value.encode (resource [DATA], {
    name      = resource [NAME],
    sortkeys  = true,
    compact   = false,
    indent    = "  ",
    fatal     = true,
    comment   = false,
    nocode    = false,
    keyignore = {
      [REPOSITORY] = true,
      [NAME      ] = true,
    },
  })
  Proxy.__metatable = mt
  return result
end

function Repository.of (proxy)
  return proxy [RESOURCE] [REPOSITORY]
end

function Repository.iterate (proxy)
  return Proxy.__pairs (proxy)
end

function Repository.size (proxy)
  return Proxy.__len (proxy)
end

--    > = Repository.export (resource)
--    > = Repository.export (repository.myotherresource)

-- Resource
-- --------

function Resource.import_proxy (repository, data)
  local name = data [Repository.resource]
  local proxy
  if name == nil then
    local placeholder = Repository.placeholder (repository)
    proxy = placeholder
  else
    proxy = repository [name]
  end
  for i = 1, #data do
    proxy = proxy [data [i]]
  end
  return proxy
end

function Resource.import_data (repository, data)
  if type (data) ~= "table" then
    return data
  elseif getmetatable (data) == nil and data [Repository.proxy] then
    return Resource.import_proxy (repository, data)
  elseif getmetatable (data) == Proxy.__metatable then
    return data
  else
    return data
  end
  local updates = {}
  for key, value in pairs (data) do
    if key == "_" then
      updates [key] = Repository.value
    elseif type (key) == "table" then
      updates [key] = Resource.import_proxy (repository, key)
    end
    if type (value) == "table" then
      data [key] = Resource.import_data (repository, value)
    end
  end
  for old_key, new_key in pairs (updates) do
    data [old_key], data [new_key] = nil, data [old_key]
  end
  return data
end

function Resource.import (repository, name, data)
  local resource = repository [RESOURCES] [name]
  if not resource then
    resource = {
      [NAME      ] = name,
      [REPOSITORY] = repository,
      [DATA      ] = false,
    }
    setmetatable (resource, Resource)
  end
  repository [RESOURCES] [name    ] = resource
  repository [CREATED  ] [resource] = true
  resource   [DATA     ] = Resource.import_data (repository, data)
  return Proxy.new (resource)
end

-- Proxy
-- -----

local pack   = table.pack   or function (...) return { ... } end
local unpack = table.unpack or unpack

function Proxy.new (resource)
  assert (getmetatable (resource) == Resource.__metatable)
  local repository = resource   [REPOSITORY]
  local proxies    = repository [PROXIES   ]
  local found      = proxies    [resource  ]
  if found then
    return found
  end
  local proxy = setmetatable ({
    [RESOURCE  ] = resource,
    [PARENT    ] = proxies,
    [KEYS      ] = {},
    [FOLLOW    ] = false,
    [PROXIES   ] = setmetatable ({}, IgnoreValues),
  }, Proxy)
  proxies [resource] = proxy
  return proxy
end

function Proxy.__serialize (proxy)
  local resource = proxy [RESOURCE]
  local keys     = proxy [KEYS    ]
  return {
    [Repository.proxy   ] = true,
    [Repository.resource] = resource [NAME],
    unpack (keys),
  }
end

function Proxy.__index (proxy, key)
  if key == "_" then
    return Proxy.value (proxy)
  end
  local proxies = proxy [PROXIES]
  local found   = proxies [key]
  if found then
    return found
  end
  local keys  = proxy [KEYS]
  local nkeys = pack (unpack (keys))
  nkeys [#nkeys+1] = key
  local result = setmetatable ({
    [RESOURCE] = proxy [RESOURCE],
    [PARENT  ] = proxy,
    [KEYS    ] = nkeys,
    [FOLLOW  ] = proxy [FOLLOW] or key == Repository.follow,
    [PROXIES ] = setmetatable ({}, IgnoreValues),
  }, Proxy)
  proxies [key] = result
  return result
end

function Proxy.__newindex (proxy, key, value)
  local resource   = proxy [RESOURCE]
  local repository = resource [REPOSITORY]
  proxy = Proxy.deplaceholderize (proxy, resource)
  proxy = Proxy.dereference (proxy)
  key   = Resource.import_data (repository, key)
  value = Resource.import_data (repository, value)
  if key == "_" then
    if  type (value) == "table"
    and getmetatable (value) == Proxy.__metatable then
      error "illegal insertion"
    else
      key = Repository.value
    end
  end
  local keys   = proxy    [KEYS]
  local parent = resource [DATA]
  for i = 1, #keys do
    local child = parent [keys [i]]
    if type (child) ~= "table"
    or getmetatable (child) == Proxy.__metatable then
      if value == nil then
        return
      else
        child = {
          [Repository.value] = child,
        }
        parent [keys [i]] = child
      end
    end
    parent = child
  end
  parent [key] = value
  -- TODO: cancel cache
end

function Proxy.__call (proxy, n)
  assert (n == nil or type (n) == "number")
  for _ = 1, n or 1 do
    proxy = proxy [Repository.follow]
  end
  return proxy
end

function Proxy.apply (f, is_iterator)
  return function (p)
    local coroutine = require "coroutine.make" ()
    local function perform (proxy, data, seen)
      local resource = proxy [RESOURCE]
      proxy = Proxy.deplaceholderize (proxy, resource)
      proxy = Proxy.dereference (proxy)
      if seen [proxy] then
        return nil
      end
      seen [proxy] = true
      local keys   = proxy [KEYS]
      -- search in resources
      local resources  = Proxy.depends (Proxy.new (resource))
      for i = #resources, 1, -1 do
        local current = resources [i] [RESOURCE] [DATA]
        for j = 1, #keys do
          if type (current) ~= "table"
          or getmetatable (current) == Proxy.__metatable then
            current = nil
            break
          end
          current = current [keys [j]]
        end
        if current ~= nil then
          f {
            proxy     = proxy,
            current   = current,
            coroutine = coroutine,
            data      = data,
          }
        end
      end
      -- special case: when we are within a `cosy:` thing, do not search
      -- for parents, as they are forbidden
      for i = 1, #keys do
        local key = keys [i]
        if type (key) == "string" and key:match "^cosy:" then
          return
        end
      end
      -- else search in parents
      local current = proxy
      for i = #keys, 0, -1 do
        local refines = Proxy.refines (current)
        for j = #refines-1, 1, -1 do
          local refined = refines [j]
          for k = i+1, #keys do
            refined = refined [keys [k]]
          end
          perform (refined, data, seen)
        end
        current = current [PARENT]
      end
    end
    local result = coroutine.wrap (function ()
      perform (p, {}, {})
    end)
    if is_iterator then
      return result
    else
      return result ()
    end
  end
end

Proxy.__pairs = Proxy.apply (function (t)
  local proxy     = t.proxy
  local current   = t.current
  local coroutine = t.coroutine
  local yielded   = t.data
  if type (current) == "table" then
    for k in pairs (current) do
      if not yielded [k] then
        yielded [k] = true
        coroutine.yield (k, proxy [k])
      end
    end
  end
end, true)

function Proxy.__ipairs (proxy)
  local coroutine = require "coroutine.make" ()
  return coroutine.wrap (function ()
    local i = 1
    while true do
      local p = proxy [i]
      if Proxy.exists (p) then
        coroutine.yield (i, p)
      else
        return nil
      end
      i = i+1
    end
  end)
end

function Proxy.__len (proxy)
  local n = 1
  while Proxy.exists (proxy [n]) do
    n = n+1
  end
  return n-1
end

Proxy.size = Proxy.__len

function Proxy.__tostring (proxy)
  local resource = proxy    [RESOURCE]
  local keys     = proxy    [KEYS    ]
  local name     = resource [NAME    ]
  local t    = { "/" .. tostring (name) .. "/" }
  for i = 1, #keys do
    t [i+1] = tostring (keys [i])
  end
  return table.concat (t, ".")
end

Proxy.value = Proxy.apply (function (t)
  local coroutine = t.coroutine
  local current   = t.current
  if type (current) ~= "table"
  or getmetatable (current) == Proxy.__metatable then
    coroutine.yield (current)
  else
    coroutine.yield (current [Repository.value])
  end
end, false)

Proxy.exists = Proxy.apply (function (t)
  local coroutine = t.coroutine
  coroutine.yield (true)
end, false)

function Proxy.deplaceholderize (proxy, res)
  local resource   = proxy    [RESOURCE  ]
  local repository = resource [REPOSITORY]
  local keys       = proxy    [KEYS      ]
  if resource ~= Repository.placeholder (repository) [RESOURCE] then
    return proxy
  end
  proxy = Proxy.new (res)
  for i = 1, #keys do
    proxy = proxy [keys [i]]
  end
  return proxy
end

function Proxy.dereference (proxy)
  if not proxy [FOLLOW] then
    return proxy
  end
  local resource = proxy [RESOURCE]
  repeat
    local current = Proxy.new (proxy [RESOURCE] or resource)
    local keys    = proxy [KEYS]
    local changed = false
    for i = 1, #keys do
      local key = keys [i]
      if key == Repository.follow then
        local target = current._
        if target == nil then
          return nil
        end
        changed = true
        proxy   = target
        for j = i+1, #keys do
          proxy = proxy [keys [j]]
        end
        break
      end
      current = current [key]
    end
  until not changed
  return proxy
end

Proxy.depends = require "c3" .new {
  superclass = function (proxy)
    local resource = proxy [RESOURCE] [DATA]
    return resource [Repository.depends]
  end,
}

Proxy.refines = require "c3" .new {
  superclass = function (proxy)
    local resource = proxy [RESOURCE]
    proxy = Proxy.deplaceholderize (proxy, resource)
    proxy = Proxy.dereference (proxy)
    local refines = proxy [Repository.refines]
    local result  = {}
    for i = 1, math.huge do
      local p = refines [i]._
      if p == nil then
        break
      end
      p = Proxy.deplaceholderize (p, resource)
      p = Proxy.dereference (p)
      result [#result+1] = p
    end
    return result
  end,
}

--[[
local repository = Repository.new ()
Repository.options (repository).create = function () end
Repository.options (repository).import = function () end

repository.a = {}
repository.b = {}
repository.c = {
  [Repository.depends] = {
    repository.a, repository.b
  }
}
print ("a", Repository.export (repository.a))
print ("b", Repository.export (repository.b))
print ("c", Repository.export (repository.c))

repository.a = {
  x = 1,
}
repository.b = {
  y = 2,
}
print ("a", Repository.export (repository.a))
print ("b", Repository.export (repository.b))
print ("c", Repository.export (repository.c))

print ("c.x", repository.c.x._)
print ("c.y", repository.c.y._)
--]]
--[==[
-- Examples
-- --------
do
  local repository = Repository.new ()
  local _          = Repository.placeholder (repository)
  Repository.options (repository).create = function () end
  Repository.options (repository).import = function () end
  repository.graph = {
    vertex_type = {
      is_vertex = true,
    },
    edge_type   = {
      is_edge = true,
    },
    something = {
      _ = true,
    }
  }
  repository.petrinet = {
    [Repository.refines] = {
      [1] = repository.graph,
    },
    place_type = {
      [Repository.refines] = {
        [1] = _.vertex_type,
      }
    },
    transition_type = {
      [Repository.refines] = {
        [1] = _.vertex_type,
      }
    },
    arc_type = {
      [Repository.refines] = {
        [1] = _.edge_type,
      }
    },
  }
  repository.philosophers = {
    a = 1,
  }
--  print (Repository.export (repository.graph))
--  print (Repository.export (repository.petrinet))
--  print "searching place_type"
--  print (Proxy.exists (repository.petrinet.place_type))
  print ("machin?", Proxy.exists (repository.petrinet.machin))
  repository.petrinet.machin = 2
  print (repository.petrinet.machin._)
  print (repository.graph.vertex_type.is_vertex._)
  print (repository.petrinet.place_type.is_vertex._)
end
--]==]

return Repository