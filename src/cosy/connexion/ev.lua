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
  end)
  ws:on_close (function ()
    result [WS] = nil
  end)
  ws:on_message (function (_, message)
    if not message then
      return
    end
    local command = json.decode (message)
    if command.action == "update" then
      update.from_patch = true
      for patch in seq (command.patches) do
        print ("Applying patch " .. tostring (patch.data))
        pcall (loadstring, patch.data)
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
    if ws.readyState == 1 then
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
  function ws.execute (f)
    local co = coroutine.create (f)
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

return connect
