-- URLs in `require`
-- =================
--
-- This module adds a package loader for URLs. It allows to fetch Lua
-- modules reachable through `http` and `https` protocols.

-- It depends on `luasocket` and `luasec`.
local http  = require "socket.http"
local https = require 'ssl.https'

-- The searcher function loads the required URL and uses it as a Lua module.
local function http_searcher (url)
  local body
  local status
  if url:find ("http://") == 1 then
    body, status = http.request (url)
  elseif url:find ("https://") == 1 then
    body, status = https.request (url)
  else
    return nil
  end
  -- The status code can be:
  -- * 200 (OK)
  -- * 3xx (Redirect)
  --
  -- Otherwise, there is an error.
  if status ~= 200 and status < 300 or status >= 400 then
    error ("Cannot fetch " .. url)
  end
  return loadstring (body)
end

-- Add the searcher to the list of searchers. As it uses the "http" prefix,
-- put is at the first position to avoid calls to the file system before.
table.insert (package.loaders, 1, http_searcher)
