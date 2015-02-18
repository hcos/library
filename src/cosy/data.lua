                 require "compat53"
coroutine.make = require "coroutine.make"

local Repository = {}
local Proxy      = {}

local function make_tag (name)
  return setmetatable ({}, {
    __tostring = function () return name end
  })
end

Repository.__metatable = "cosy.data"
Proxy     .__metatable = "cosy.data.proxy"

Repository.CONTENTS   = make_tag "Repository.CONTENTS"
Repository.LINEARIZED = make_tag "Repository.LINEARIZED"

Proxy.REPOSITORY      = make_tag "Proxy.REPOSITORY"
Proxy.KEYS            = make_tag "Proxy.KEYS"

Repository.VALUE    = "_"
Repository.DEPENDS  = "cosy:depends"
Repository.INHERITS = "cosy:inherits"
Repository.REFERS   = "cosy:refers"

function Repository.as_table (repository)
  return setmetatable ({
    [Repository.CONTENTS  ] = repository [Repository.CONTENTS  ],
    [Repository.LINEARIZED] = repository [Repository.LINEARIZED],
  }, {
    __index = function (r, k)
      return Repository.get (r, k)
    end,
    __newindex = function (r, k, v)
      Repository.set (r, k, v)
    end,
  })
end

function Repository.new ()
  return setmetatable ({
    [Repository.CONTENTS  ] = {},
    [Repository.LINEARIZED] = setmetatable ({}, { __mode = "kv" })
  }, Repository)
end

function Repository.get (repository, key)
  local found = repository [Repository.CONTENTS] [key]
  if found == nil then
    return nil
  else
    return setmetatable ({
      [Proxy.REPOSITORY] = repository,
      [Proxy.KEYS      ] = { key },
    }, Proxy)
  end
end

function Repository.raw (repository, key)
  if key == nil then
    return repository [Repository.CONTENTS]
  else
    return repository [Repository.CONTENTS] [key]
  end
end

function Repository.deproxify (t, within)
  if type (t) ~= "table" then
    return t
  end
  if getmetatable (t) == Proxy.__metatable then
    if within == Repository.DEPENDS then
      t = t [Proxy.KEYS] [1]
    elseif within == Repository.INHERITS 
        or within == Repository.REFERS   then
      local keys = t [Proxy.KEYS]
      local path = {}
      for i = 2, #keys do
        path [i-1] = keys [i]
      end
      t = path
    else
      local keys = t [Proxy.KEYS]
      local path = {}
      for i = 2, #keys do
        path [i-1] = keys [i]
      end
      t = {
        [Repository.REFERS ] = path,
      }
    end
    return t
  end
  for k, v in pairs (t) do
    local w = within
    if k == Repository.DEPENDS
    or k == Repository.INHERITS
    or k == Repository.REFERS then
      w = k
    end
    t [k] = Repository.deproxify (v, w)
  end
  return t
end

function Repository.set (repository, key, value)
  repository [Repository.CONTENTS] [key] = Repository.deproxify (value)
end

Repository.placeholder = setmetatable ({
  [Proxy.REPOSITORY] = false,
  [Proxy.KEYS      ] = { false },
}, Proxy)

function Repository.linearize (repository, key)
  local function linearize (t)
    local cached = repository [Repository.LINEARIZED] [t]
    if cached then
      return cached
    end
    -- Prepare:
    local depends = t [Repository.DEPENDS]
    local l, n = {}, {}
    if depends then
      depends = table.pack (table.unpack (depends))
      for i = 1, #depends do
        depends [i] = Repository.raw (repository, depends [i])
      end
      l [#l+1] = depends
      n [#n+1] = #depends
      for i = 1, #depends do
        l [#l+1] = linearize (depends [i])
        n [#n+1] = # (l [#l])
      end
    end
    l [#l+1] = { t }
    n [#n+1] = 1
--[[
    do
      local dump = {}
      for i = 1, #l do
        local x = {}
        for j = 1, #(l [i]) do
          x [j] = l [i] [j].name
        end
        dump [i] = "{ " .. table.concat (x, ", ") .. " }"
      end
      print ("l", table.concat (dump, ", "))
    end
--]]
    -- Compute tails:
    local tails = {}
    for i = 1, #l do
      local v = l [i]
      for j = 1, #v do
        local w   = v [j]
        tails [w] = (tails [w] or 0) + 1
      end
    end
--[[
    do
      local dump = {}
      for k, v in pairs (tails) do
        dump [#dump+1] = k.name .. " = " .. tostring (v)
      end
      print ("tails", table.concat (dump, ", "))
    end
--]]
    -- Compute linearization:
    local result = {}
    while #l ~= 0 do
      for i = #l, 1, -1 do
        local vl, vn  = l [i], n [i]
        local first   = vl [vn]
        tails [first] = tails [first] - 1
      end
      local head
      for i = #l, 1, -1 do
        local vl, vn = l [i], n [i]
        local first  = vl [vn]
        if tails [first] == 0 then
          head = first
          break
        end
      end
      if head == nil then
        error "Linearization failed"
      end
      result [#result + 1] = head
      for i = 1, #l do
        local vl, vn = l [i], n [i]
        local first  = vl [vn]
        if first == head then
          n [i] = n [i] - 1
        else
          tails [first] = tails [first] + 1
        end
      end
      local nl, nn = {}, {}
      for i = 1, #l do
        if n [i] ~= 0 then
          nl [#nl+1] = l [i]
          nn [#nn+1] = n [i]
        end
      end
      l, n = nl, nn
    end
    for i = 1, #result/2 do
      result [i], result [#result-i+1] = result [#result-i+1], result [i]
    end
    repository [Repository.LINEARIZED] [t] = result
--[[
    do
      local dump = {}
      for i = 1, #result do
        dump [i] = result [i].name
      end
      print ("result", table.concat (dump, ", "))
    end
--]]
    return result
  end
  return linearize (Repository.raw (repository, key))
end

function Proxy.__index (proxy, key)
  if type (key) == "table" then
    error "Not implemented"
  end
  if key ~= "_" then
    local repository = proxy [Proxy.REPOSITORY]
    local keys       = proxy [Proxy.KEYS      ]
    keys = table.pack (table.unpack (keys))
    keys [#keys+1] = key
    return setmetatable ({
      [Proxy.REPOSITORY] = repository,
      [Proxy.KEYS      ] = keys,
    }, Proxy)
  else
    local keys       = proxy [Proxy.KEYS]
    local repository = proxy [Proxy.REPOSITORY]
    local layers     = Repository.linearize (repository, keys [1])
    for i = #layers, 1, -1 do
      local data = layers [i]
      for j = 2, #keys do
        if type (data) ~= "table" then
          data = nil
          break
        end
        data = data [keys [j]]
        if data == nil then
          break
        end
        -- Special cases:
        local key = keys [j]
        if key == Repository.REFERS then
          local pkeys = { keys [1] }
          for k = 1, #data do
            pkeys [#pkeys + 1] = data [k]
          end
          for k = j+1, #keys do
            pkeys [#pkeys+1] = keys [k]
          end
          proxy = setmetatable ({
            [Proxy.REPOSITORY] = repository,
            [Proxy.KEYS      ] = pkeys,
          }, Proxy)
          return proxy._
        elseif key == Repository.INHERITS then
          -- TODO
          error "Not implemented"
        elseif key == Repository.DEPENDS then
          -- Do nothing
        end
      end
      if data ~= nil then
        if type (data) == "table" then
          return data [Repository.VALUE]
        else
          return data
        end
      end
    end
    return nil
  end
end

function Proxy.__call (proxy, n)
  if n == nil then
    n = 1
  end
  local repository = proxy [Proxy.REPOSITORY]
  local keys       = proxy [Proxy.KEYS      ]
  keys = table.pack (table.unpack (keys))
  for _ = 1, n do
    keys [#keys+1] = Repository.REFERS
  end
  return setmetatable ({
    [Proxy.REPOSITORY] = repository,
    [Proxy.KEYS      ] = keys,
  }, Proxy)
end

function Proxy.__newindex (proxy, key, value)
  if type (key) == "table" then
    error "Not implemented"
  end
  value = Repository.deproxify (value)
  local keys = proxy [Proxy.KEYS]
  if key ~= "_" then
    keys = table.pack (table.unpack (keys))
    keys [#keys + 1] = key
  end
  local data = proxy [Proxy.REPOSITORY]
  data = Repository.raw (data)
  for i = 1, #keys-1 do
    local key = keys [i]
    if data [key] == nil then
      data [key] = {}
    end
    data = data [key]
  end
  local last = keys [#keys]
  if key == "_" then
    if type (value) == "table" then
      error "Illegal value"
    elseif type (data [last]) == "table" then
      data [last] [Repository.VALUE] = value
    else
      data [last] = value
    end
  else
    data [last] = value
  end
end

Proxy.coroutine = coroutine.make ()

function Proxy.__pairs (proxy)
  error "Not implemented"
  return Proxy.coroutine.wrap (function ()
  end)
end

function Proxy.__len (proxy)
  error "Not implemented"
end

function Proxy.__tostring (proxy)
  error "Not implemented"
end

function Proxy.__unm (proxy)
  error "Not implemented"
end

function Proxy.__add (lhs, rhs)
  error "Not implemented"
end

function Proxy.__sub (lhs, rhs)
  error "Not implemented"
end

function Proxy.__mul (lhs, rhs)
  error "Not implemented"
end

function Proxy.__div (lhs, rhs)
  error "Not implemented"
end

function Proxy.__mod (lhs, rhs)
  error "Not implemented"
end

function Proxy.__pow (lhs, rhs)
  error "Not implemented"
end

function Proxy.__concat (lhs, rhs)
  error "Not implemented"
end

function Proxy.__eq (lhs, rhs)
  local lrepository = lhs [Proxy.REPOSITORY]
  local rrepository = rhs [Proxy.REPOSITORY]
  if lrepository [Repository.CONTENTS] ~= rrepository [Repository.CONTENTS] then
    return false
  end
  local lkeys = lhs [Proxy.KEYS]
  local rkeys = rhs [Proxy.KEYS]
  if #lkeys ~= #rkeys then
    return false
  end
  for i = 1, #lkeys do
    if lkeys [i] ~= rkeys [i] then
      return false
    end
  end
  return true
end

function Proxy.__lt (lhs, rhs)
  error "Not implemented"
end

function Proxy.__le (lhs, rhs)
  error "Not implemented"
end

return Repository