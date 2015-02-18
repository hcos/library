require "compat52"

local Repository = {}
local Proxy      = {}

Repository.CONTENTS   =
  setmetatable ({}, { __tostring = function () return "Repository.CONTENTS"   end })
Repository.LINEARIZED =
  setmetatable ({}, { __tostring = function () return "Repository.LINEARIZED" end })
Proxy.REPOSITORY      =
  setmetatable ({}, { __tostring = function () return "Proxy.REPOSITORY"      end })
Proxy.KEYS            =
  setmetatable ({}, { __tostring = function () return "Proxy.KEYS"            end })

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

function Repository.new (options)
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

function Repository.set (repository, key, value)
  local function replace_proxy (t, within)
    if type (t) ~= "table" then
      return t
    end
    if getmetatable (t) == Proxy then
      if within == Repository.DEPENDS then
        t = t [Proxy.KEYS] [1]
      elseif within == Repository.INHERITS 
          or within == Repository.REFERS   then
        t = t [Proxy.KEYS]
      else
        t = {
          [Repository.REFERS ] = t [Proxy.KEYS],
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
      t [k] = replace_proxy (v, w)
    end
    return t
  end
  repository [Repository.CONTENTS] [key] = replace_proxy (value)
end

Repository.placeholder = setmetatable ({
  [Proxy.REPOSITORY] = false,
  [Proxy.KEYS      ] = {},
}, Proxy)

--[[
function Repository.new (data)
  local function replace_proxy (t, within)
    if type (t) ~= "table" then
      return t
    end
    if getmetatable (t) == Proxy then
      if within == Repository.DEPENDS then
        t = t [Proxy.KEYS] [1]
      elseif within == Repository.INHERITS 
          or within == Repository.REFERS   then
        local keys = t [Proxy.KEYS]
        t = {}
        for i = 2, #keys do
          t [i-1] = keys [i]
        end
      else
        local keys   = t [Proxy.KEYS]
        local refers = {}
        t = {
          [Repository.REFERS ] = refers,
        }
        for i = 2, #keys do
          refers [i-1] = keys [i]
        end
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
      t [k] = replace_proxy (v, w)
    end
    return t
  end
  data = replace_proxy (data)
  return setmetatable ({
    [Proxy.KEYS] = { data },
  }, Proxy)
end
--]]

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

function Proxy.get (proxy)
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
        return Proxy.get (proxy)
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

function Proxy.__index (proxy, key)
  -- TODO: what happens when the key is a table or proxy?
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
    return Proxy.get (proxy)
  end
end

function Proxy.__call (proxy, n)
  -- TODO: what happens when the key is a table or proxy?
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
  local keys = proxy [Proxy.KEYS]
  if key == "_" then
    key   = keys [#keys]
    keys  = table.pack (table.unpack (keys))
    keys [#keys] = nil
    proxy = setmetatable ({
      [Proxy.KEYS ] = keys,
    }, Proxy)
    proxy [key] = value
    return
  end
  -- Fix value
  
  local data = proxy [Proxy.DATA]
  for i = 1, #keys do
    if data [keys [i]] == nil then
      data [keys [i]] = {}
    end
    data = data [keys [i]]
  end
  -- TODO
end

return Repository