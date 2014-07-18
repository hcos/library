require "cosy.lang.cosy"

local observed = require "cosy.lang.view.observed"
observed [#observed + 1] = require "cosy.lang.view.update"

local global = _ENV or _G
global.cosy = observed (global.cosy)

local ev        = require "ev"
local sha1      = require "sha1"
local json      = require "dkjson"
local websocket = require "websocket"

local seq    = require "cosy.lang.iterators" . seq
local tags   = require "cosy.lang.tags"
local update = require "cosy.lang.view.update"

local WS       = tags.WS
local RESOURCE = tags.RESOURCE
local UPDATES  = tags.UPDATES

local function connect (parameters)
  local token    = parameters.token
  local resource = parameters.resource
  local editor   = parameters.editor
  local ws       = websocket.client.ev { timeout = 2 }
  local result   = {
    [RESOURCE] = resource,
    [WS      ] = ws,
    [UPDATES ] = {},
  }
  ws.token   = token
  ws:connect (editor, 'cosy')
  ws:on_open (function ()
    ws:request {
      action   = "set-resource",
      token    = token,
      resource = resource,
    }
    ws:request {
      action   = "get-patches",
      token    = token,
    }
  end)
  ws:on_close (function ()
    result [WS] = nil
  end)
  ws:on_message (function (_, message)
    if not message then
      return
    end
    local command = json.decode (message)
    if command.patches then
      update.from_patch = true
      for patch in seq (command.patches) do
        local ok, err = pcall (loadstring (patch.data))
        if not ok then
          print (err)
        end
        local updates = result [UPDATES]
        updates [#updates + 1] = patch.data
      end
      update.from_patch = nil
    else
      -- do nothing
    end
  end)
  ws:on_error (function (_, err)
    print (err)
--    ws:close ()
  end)
  function ws.request (_, command)
    local str = json.encode (command)
    command.request_id = sha1 (tostring (os.time()) .. "+" .. str)
    command.token = ws.token
    if ws.state == "OPEN" then
      ws:send (json.encode (command))
    end
  end
  function ws.patch (_, patch)
    local command = {
      action = "add-patch",
      data   = patch,
    }
    local str = json.encode (command)
    command.request_id = sha1 (tostring (os.time()) .. "+" .. str)
    command.token = ws.token
    if ws.state == "OPEN" then
      ws:send (json.encode (command))
    end
  end
  function ws.execute (f, again)
    local co = coroutine.create (function ()
      local ok, err = pcall (f)
      if not ok then
        print (err)
      end
    end)
    local timer = ev.Timer.new (function (_, timer, _)
      local _, delay = coroutine.resume (co)
      if coroutine.status (co) == "dead" then
        timer:stop (ev.Loop.default)
      else
        timer:again (ev.Loop.default, delay)
      end
    end, 1)
    timer:start (ev.Loop.default)
  end
  function ws.loop ()
    ev.Loop.default:loop ()
  end
  function ws.stop ()
    ev.Loop.default:unloop ()
  end
  global.cosy [resource] = result
  return global.cosy [resource]
end


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

return connect
