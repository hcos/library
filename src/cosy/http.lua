local hotswap  = require "hotswap"
local Url      = require "socket.url"
local C3       = require "c3"
                 require "cosy.string"

local Headers = {}

Headers.sorted = {}

Headers.loaded = setmetatable ({}, {
  __index = function (_, key)
    local handler, new = hotswap ("cosy.http." .. key, true)
    if not handler then
      if Headers.loaded [key] then
        for i = 1, #Headers.sorted do
          if Headers.sorted [i] == key then
            table.remove (Headers.sorted, i)
            break
          end
        end
      end
      Headers.loaded [key] = false
    elseif new then
      if not Headers.loaded [key] then
        Headers.sorted [#Headers.sorted+1] = key
      end
      Headers.loaded [key] = handler
      Headers.loaded ["_"] = {
        depends = Headers.sorted,
      }
      Headers.sorted = Headers.sort "_"
      Headers.sorted [#Headers.sorted] = nil
    end
    return handler
  end,
})

Headers.sort = C3.new {
  superclass = function (name)
    local header = Headers.loaded [name]
    return header and header.depends or nil
  end,
}

function Headers.__newindex (headers, key, value)
  local _ = Headers.loaded [key]
  rawset (headers, key, value)
end

return function (context)
  local socket    = context.socket
  local firstline = socket:receive "*l"
  if firstline == nil then
    context.continue = false
    return
  end
  -- Build request and response:
  local method, uri, protocol = firstline:match "^(%a+)%s+(%S+)%s+(%S+)"
  context.request          = Url.parse (uri)
  context.request.uri      = uri
  context.request.protocol = protocol
  context.request.method   = method
  context.request.headers  = setmetatable ({}, Headers)
  context.response = {
    protocol = context.request.protocol,
    status   = nil,
    message  = nil,
    headers  = setmetatable ({}, Headers),
  }
  -- Extract headers:
  while true do
    local line = socket:receive "*l"
    if line == "" then
      break
    end
    local name, value = line:match "([^:]+):%s*(.*)"
    name  = name :trim ():lower ()
    value = value:trim ()
    context.request.headers [name] = value
  end
  -- Extract parameters:
  for parameter in (context.request.query or ""):gmatch "([^;&]+)" do
    local name, value = parameter:match "([^=]+)=(.*)"
    name  = Url.unescape (name ):gsub ("+", " ")
    value = Url.unescape (value):gsub ("+", " ")
    context.request.parameters [name] = value
  end
  -- Handle headers:
  for i = 1, #Headers.sorted do
    local name   = Headers.sorted [i]
    local header = Headers.loaded [name]
    if header then
      header.request (context)
    end
  end
  context.http.handler (context)
  -- Handle headers:
  for i = #Headers.sorted, 1, -1 do
    local name   = Headers.sorted [i]
    local header = Headers.loaded [name]
    if header then
      header.response (context)
    end
  end
  -- Send response:
  local response = {}
  response [1] = "%{protocol} %{status} %{message}" % {
    protocol = context.response.protocol,
    status   = context.response.status,
    message  = context.response.message,
  }
  for name, value in pairs (context.response.headers) do
    response [#response + 1] = "%{name}: %{value}" % {
      name  = name,
      value = value,
    }
  end
  response [#response + 1] = ""
  response [#response + 1] = ""
  if context.response.body == nil then
    socket:send (table.concat (response, "\r\n"))
  elseif type (context.response.body) == "string" then
    response [#response + 1] = context.response.body
    socket:send (table.concat (response, "\r\n"))
  end
  return context.next
end