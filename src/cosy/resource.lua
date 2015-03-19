local Platform         = require "cosy.platform"

local Repository       = {}
Repository.__metatable = "cosy.data"
Repository.value       = "_"
Repository.proxy       = "cosy:proxy"
Repository.resource    = "cosy:resource"
Repository.depends     = "cosy:depends"
Repository.refers      = "cosy:refers"
Repository.refines     = "cosy:refines"

local Resource         = {}
Resource.__metatable   = "cosy.data.resource"

local Proxy            = {}
Proxy.__metatable      = "cosy.data.proxy"

local Cache            = {}
Cache.__metatable      = "cosy.data.cache"
Cache.__mode           = "k"

local Cleanable        = {}
Cache.__metatable      = "cosy.data.cleanable"
Cache.__mode           = "k"

local function make_tag (name)
  return setmetatable ({}, {
    __tostring = function () return name end
  })
end

local CACHES     = make_tag "CACHES"
local COROUTINE  = make_tag "COROUTINE"
local OPTIONS    = make_tag "OPTIONS"
local PROXIES    = make_tag "PROXIES"

local KEYS       = make_tag "KEYS"
local NAME       = make_tag "NAME"
local PARENT     = make_tag "PARENT"
local REPOSITORY = make_tag "REPOSITORY"
local RESOURCES  = make_tag "RESOURCES"
local RESOURCE   = make_tag "RESOURCE"

-- Repository
-- ----------

function Repository.new ()
  local repository = setmetatable ({
    [CACHES    ] = {},
    [COROUTINE ] = require "coroutine.make" (),
    [OPTIONS   ] = {
      create = nil,
      import = nil,
    },
    [PROXIES   ] = setmetatable ({}, Cache),
    [RESOURCES ] = setmetatable ({}, Cleanable),
  }, Repository)
  return repository
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
  local found    = repository [RESOURCES] [key]
  if found then
    return found
  end
  local import   = repository [OPTIONS].import
  local data     = import (repository, key)
  local resource = Resource.import (repository, key, data)
  repository [RESOURCES] [key] = resource
  return resource
end

--    > resource = repository.myresource

function Repository.__newindex (repository, key, data)
  if data == nil then
    repository [RESOURCES] [key] = nil
    return
  end
  local create = repository [OPTIONS].create
  create (repository, key)
  local resource = Resource.import (repository, key, data)
  repository [RESOURCES] [key] = resource
end


function Repository.placeholder (repository)
  return Proxy.new (setmetatable ({
    [REPOSITORY] = repository,
  }, Resource))
end

function Repository.flatten (resource)
  error "Not implemented yet"
end

function Repository.export (proxy)
  assert (# proxy [KEYS] == 0)
  local resource    = proxy    [RESOURCE  ]
  local mt          = Proxy.__metatable
  Proxy.__metatable = nil
  local result     = Platform.table.dump (resource, {
    sortkeys  = true,
    compact   = true,
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

--    > = Repository.export (resource)
--    > = Repository.export (repository.myotherresource)

-- Resource
-- --------

function Resource.import (repository, name, data)
  if type (data) ~= "table" then
    data = { _ = data }
  end
  assert (getmetatable (data) == nil)
  local resource    = data
  local placeholder = Repository.placeholder (repository)
  local function import_proxy (data)
    local name = data [Repository.resource]
    local proxy
    if name ~= nil then
      proxy = repository [name]
    else
      proxy = placeholder
    end
    for i = 1, #data do
      proxy = proxy [data [i]]
    end
    return proxy
  end
  local function import_data (data)
    if type (data) ~= "table" then
      return
    end
    local updates = {}
    for key, value in pairs (data) do
      if type (key) == "table" and key [Repository.proxy] then
        updates [key] = import_proxy (key)
      end
      if type (value) == "table" and value [Repository.proxy] then
        data [key] = import_proxy (value)
      elseif type (value) == "table" then
        import_data (value)
      end
    end
    for old_key, new_key in pairs (updates) do
      data [old_key], data [new_key] = nil, data [old_key]
    end
  end
  import_data (resource)
  resource [NAME      ] = name
  resource [REPOSITORY] = repository
  setmetatable (resource, Resource)
  return Proxy.new (resource)
end

-- Proxy
-- -----

table.unpack = table.unpack or unpack

function Proxy.new (resource)
  assert (getmetatable (resource) == Resource.__metatable)
  local repository = resource   [REPOSITORY]
  local proxies    = repository [PROXIES   ]
  local found      = proxies    [resource]
  if found then
    return found
  end
  local proxy = setmetatable ({
    [RESOURCE] = resource,
    [PARENT  ] = false,
    [KEYS    ] = {},
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
    table.unpack (keys),
  }
end

function Proxy.value (proxy)
  error "Not implemented yet"
end

function Proxy.dereference (proxy)
  error "Not implemented yet"
end

-- Examples
-- --------
do
  local repository = Repository.new ()
  Repository.options (repository).create = function () end
  Repository.options (repository).import = function ()
    return { a = 1, b = 2 }
  end
  local resource = repository.myresource
  print (Repository.export (resource))
  repository.otherresource = {
    c = resource,
    [resource] = 1,
    d = { [resource] = 2 },
  }
  print (Repository.export (resource))
  print (Repository.export (repository.myresource))
  print (Repository.export (repository.otherresource))
  local str = Repository.export (repository.otherresource)
  local _, loaded = Platform.table.decode (str)
  repository.myresource    = nil
  repository.otherresource = nil
  print "loading"
  repository.loaded        = loaded
  print (Repository.export (repository.myresource))
  print (Repository.export (repository.loaded))
end

return Repository