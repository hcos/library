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

CURRENT    = make_tag "CURRENT"
CONTENTS   = make_tag "CONTENTS"
LINEARIZED = make_tag "LINEARIZED"
OPTIONS    = make_tag "OPTIONS"
REPOSITORY = make_tag "REPOSITORY"
KEYS       = make_tag "KEYS"

Repository.VALUE    = "_"
Repository.DEPENDS  = "cosy:depends"
Repository.INHERITS = "cosy:inherits"
Repository.REFERS   = "cosy:refers"

local Options = {}

function Options.new ()
  return {
    filter   = nil,
    on_read  = nil,
    on_write = nil,
  }
end

function Options.wrap (options)
  return setmetatable ({
    [OPTIONS] = options,
    [CURRENT] = options,
  }, Options)
end

function Options.__index (options, key)
  local found = options [CURRENT] [key]
  if type (found) ~= "table" then
    return found
  else
    return setmetatable ({
      [OPTIONS] = options [OPTIONS],
      [CURRENT] = found,
    }, Options)
  end
end

function Options.__newindex (options, key, value)
  local found = options [CURRENT] [key]
  options [CURRENT] [key] = value
  local err = Options.check (options [OPTIONS])
  if err then
    options [CURRENT] [key] = found
    error (err)
  end
end

function Options.check (options)
  local function is_function (f)
    return type (f) == "function"
        or type (f) == "thread"
        or (    type (f) == "table"
            and getmetatable (f) ~= nil
            and getmetatable (f).__call ~= nil)
  end
  for key, value in pairs (options) do
    if key == "filter" then
      if not is_function (value) then
        return "options.filter must be a function"
      end
    elseif key == "on_read" then
      if not is_function (value) then
        return "options.on_read must be a function"
      end
    elseif key == "on_write" then
      if not is_function (value) then
        return "options.on_write must be a function"
      end
    else
      error ("unknown option: " .. tostring (key))
    end
  end
end

function Repository.new ()
  return setmetatable ({
    [CONTENTS  ] = {},
    [LINEARIZED] = setmetatable ({}, { __mode = "kv" }),
    [OPTIONS   ] = Options.new (),
  }, Repository)
end

function Repository.__index (repository, key)
  local found = repository [CONTENTS] [key]
  if found == nil then
    return nil
  else
    return setmetatable ({
      [REPOSITORY] = repository,
      [KEYS      ] = { key },
      [OPTIONS   ] = {},
    }, Proxy)
  end
end

function Repository.__newindex (repository, key, value)
  repository [CONTENTS] [key] = Repository.deproxify (value)
end

function Repository.raw (repository, key)
  if key == nil then
    return repository [CONTENTS]
  else
    return repository [CONTENTS] [key]
  end
end

function Repository.options (repository)
  return Options.wrap (repository [OPTIONS])
end

function Repository.deproxify (t, within)
  local deproxify = Repository.deproxify
  if type (t) ~= "table" then
    return t
  end
  if getmetatable (t) == Proxy.__metatable then
    if within == Repository.DEPENDS then
      t = t [KEYS] [1]
    elseif within == Repository.INHERITS 
        or within == Repository.REFERS then
      local keys = t [KEYS]
      local path = {}
      for i = 2, #keys do
        path [i-1] = keys [i]
      end
      t = path
    else
      local keys = t [KEYS]
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
    t [k] = deproxify (v, w)
  end
  return t
end

Repository.placeholder = setmetatable ({
  [REPOSITORY] = false,
  [KEYS      ] = { false },
  [OPTIONS   ] = {},
}, Proxy)

function Repository.linearize (repository, key)
  local function linearize (t, seen)
    local cached = repository [LINEARIZED] [t]
    if cached then
      return cached
    end
    if seen [t] then
      return {}
    end
    seen [t] = true
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
        local linearized = linearize (depends [i], seen)
        if #linearized ~= 0 then
          local ll = {}
          for j = 1, #linearized do
            local x = linearized [j]
            if x ~= t then
              ll [#ll+1] = x
            end
          end
          l [#l+1] = ll
          n [#n+1] = # (l [#l])
        end
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
    repository [LINEARIZED] [t] = result
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
  return linearize (Repository.raw (repository, key), {})
end

function Proxy.__index (proxy, key)
  if type (key) == "table" then
    print (key)
    error "Not implemented"
  end
  if key ~= "_" then
    local repository = proxy [REPOSITORY]
    local keys       = proxy [KEYS      ]
    local options    = proxy [OPTIONS   ]
    keys = table.pack (table.unpack (keys))
    keys [#keys+1] = key
    return setmetatable ({
      [REPOSITORY] = repository,
      [KEYS      ] = keys,
      [OPTIONS   ] = options,
    }, Proxy)
  else
    local repository = proxy [REPOSITORY]
    local keys       = proxy [KEYS]
    local options    = proxy [OPTIONS]
    local within     = { within = true }
    local filter     = repository [OPTIONS].filter
    local on_read    = repository [OPTIONS].on_read
    local layers     = Repository.linearize (repository, keys [1])
    if not options.within and filter then
      nkeys = {}
      for i = 1, #keys do
        nkeys [#nkeys+1] = keys [i]
        if not filter (setmetatable ({
            [REPOSITORY] = repository,
            [KEYS      ] = nkeys,
            [OPTIONS   ] = within,
          }, Proxy)) then
          return nil
        end
      end
    end
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
            [REPOSITORY] = repository,
            [KEYS      ] = pkeys,
            [OPTIONS   ] = options,
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
        local result
        if type (data) == "table" then
          result = data [Repository.VALUE]
        else
          result = data
        end
        if not options.within and on_read then
          on_read (proxy, result)
        end
        return result
      end
    end
    return nil
  end
end

function Proxy.__call (proxy, n)
  if n == nil then
    n = 1
  end
  local repository = proxy [REPOSITORY]
  local keys       = proxy [KEYS      ]
  local options    = proxy [OPTIONS   ]
  keys = table.pack (table.unpack (keys))
  for _ = 1, n do
    keys [#keys+1] = Repository.REFERS
  end
  return setmetatable ({
    [REPOSITORY] = repository,
    [KEYS      ] = keys,
    [OPTIONS   ] = options,
  }, Proxy)
end

function Proxy.__newindex (proxy, key, value)
  if type (key) == "table" then
    error "Not implemented"
  end
  value = Repository.deproxify (value)
  local keys = proxy [KEYS]
  if key ~= "_" then
    keys = table.pack (table.unpack (keys))
    keys [#keys + 1] = key
  end
  local data = proxy [REPOSITORY]
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
  local repository = proxy [REPOSITORY]
  local options    = proxy [OPTIONS]
  local on_write   = repository [OPTIONS].on_write
  if not options.within and on_write then
    on_write (proxy, key, value)
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
  local lrepository = lhs [REPOSITORY]
  local rrepository = rhs [REPOSITORY]
  if lrepository [CONTENTS] ~= rrepository [CONTENTS] then
    return false
  end
  local lkeys = lhs [KEYS]
  local rkeys = rhs [KEYS]
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