--local global = _ENV or _G

local result = {}

local http
local https

pcall (function ()
  http = require "socket.http"
end)
pcall (function ()
  https = require "ssl.https"
end)

local function select_implementation (x)
  if type (x) == "string" then
    if x:find "http://" == 1 then
      return http
    elseif x:find "https://" == 1 then
      return https
    end
  elseif type (x) == "table" then
    if x.url:find "http://" == 1 then
      return http
    elseif x.url:find "https://" == 1 then
      return https
    end
  end
  assert (false)
end

if http and https then
  result.request = function (arg1, arg2)
    local implementation = select_implementation (arg1)
    return implementation.request (arg1, arg2)
  end
end

return result
