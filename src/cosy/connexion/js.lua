require "cosy.lang.cosy"

local sha1      = require "sha1"
local json      = require "dkjson"

local seq    = require "cosy.lang.iterators" . seq
local tags   = require "cosy.lang.tags"
local update = require "cosy.lang.view.update"

local WS      = tags.WS
local URL     = tags.URL
local UPDATES = tags.UPDATES

local function connect (parameters)
  local token    = parameters.token
  local resource = parameters.resource
  local editor   = parameters.editor
  local ws       = js.global:websocket (editor)
  local result   = {
    [URL    ] = resource,
    [WS     ] = ws,
    [UPDATES] = {},
  }
  ws.token   = token
  function ws:onopen ()
    ws:request {
      action   = "set-resource",
      token    = token,
      resource = resource,
    }
  end
  function ws:onclose ()
    result [WS] = nil
  end
  function ws:onmessage (event)
    local message = event.data
    print (message)
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
  end
  function ws:onerror ()
    ws:close ()
  end
  function ws:request (command)
    local str = json.encode (command)
    command.request_id = sha1 (tostring (os.time()) .. "+" .. str)
    command.token = ws.token
    if ws.readyState == 1 then
      ws:send (json.encode (command))
    end
  end
  function ws:patch (str)
    local command = {
      action = "add-patch",
      data   = str,
    }
    local str = json.encode (command)
    command.request_id = sha1 (tostring (os.time()) .. "+" .. str)
    command.token = ws.token
    if ws.readyState == 1 then
      ws:send (json.encode (command))
    end
  end
  cosy [resource] = result
  return cosy [resource]
end

return connect
