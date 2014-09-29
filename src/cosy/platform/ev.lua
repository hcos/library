local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local http       = require "socket.http"
local https      = require "ssl.https"

local logging    = require "logging"
logging.console  = require "logging.console"

local GLOBAL = _G or _ENV
local cosy = GLOBAL.cosy
local meta = GLOBAL.meta

local Platform = {}

Platform.__index = Platform

function Platform:log (message)
  ignore (self)
  logger:debug (message)
end

function Platform:info (message)
  ignore (self)
  logger:info (message)
end

function Platform:warn (message)
  ignore (self)
  logger:warn (message)
end

function Platform:error (message)
  ignore (self)
  logger:error (message)
end

function Platform:send (message)
  if self.websocket.readyState == 1 then
    message.token = self.token
    self.websocket:send (json.encode (message))
  else
    self:log ("Unable to send: " .. json.encode (message))
  end
end

local function load_url (url)
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
  -- Otherwise, there is an error.
  if status ~= 200 and status < 300 or status >= 400 then
    error ("Cannot fetch " .. url)
  end
  return body
end

function Platform.new (meta)
  -- TODO: cross-domain + authentication
  local username = meta.editor.username ()
  local password = meta.editor.password ()
  local url      = meta.editor.url ()
  if username then
    url = url:gsub ("^https://", "https://${username}:${password}@" % {
      username = username,
      password = password
    })
  end
  local editor_info = load_url (url)
  if not editor_info then
    Platform:warn ("Cannot get editor ${editor_url} from repository." % {
      editor_url = meta.editor.url ()
    })
    return setmetatable ({
      meta = meta,
    }, Platform)
  end
  editor_info = json.decode (editor_info)
  meta.editor.token = editor_info.token
  meta.editor.url   = editor_info.url
  local websocket = websocket.client.ev { timeout = 2 }
  websocket:connect (editor_info.url, "cosy")
  websocket:on_open (function ()
  end)
  websocket:on_close (function ()
  end)
  websocket:on_message (function (_, message)
    if not message then
      return
    end
  end)
  websocket:on_error (function (_, err)
  end)
  --[[
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
  --]]
  return setmetatable ({
    meta      = meta,
    websocket = websocket,
  }, Platform)
end

function Platform:close ()
end

return connect
