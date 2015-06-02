local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local I18n          = require "cosy.i18n"
local Value         = require "cosy.value"
local Scheduler     = require "cosy.scheduler"

local i18n   = I18n.load (require "cosy.library-i18n")
i18n._locale = Configuration.locale._

local m18n   = I18n.load (require "cosy.methods-i18n")
m18n._locale = Configuration.locale._

local Internal   = Configuration / "default"
Internal.library = {
  timeout = 2,
}

local Library   = {}
local Client    = {}
local Operation = {}

local function threadof (f, ...)
  if Scheduler._running then
    f (...)
  else
    Scheduler.addthread (f, ...)
    Scheduler.loop ()
  end
end

function Client.connect (client)
  local url = "ws://{{{host}}}:{{{port}}}/ws" % {
    host = client.host,
    port = client.port,
  }
  if _G.js then
    client._ws = _G.js.new (_G.window.WebSocket, url, "cosy")
  else
    local Websocket = require "websocket"
    client._ws = Websocket.client.ev {
      timeout = Configuration.library.timeout._,
      loop    = Scheduler._loop,
    }
  end
  client._connect       = function ()
    client._status = "closed"
    client._ws:connect (url, "cosy")
    client._co = coroutine.running ()
    Scheduler.sleep (-math.huge)
  end
  client._ws.onopen     = function ()
    client._status = "opened"
    Scheduler.wakeup (client._co)
  end
  client._ws.onclose    = function ()
    client._status = "closed"
    Scheduler.wakeup (client._co)
  end
  client._ws.onmessage  = function (_, event)
    local message 
    if _G.js then
      message = event.data
    else
      message = event
    end
    message = Value.decode (message)
    local identifier = message.identifier
    if identifier then
      client._results [identifier] = message
      Scheduler.wakeup (client._waiting [identifier])
    end
  end
  client._ws.onerror    = function (_, err)
    client._status = "closed"
    client._err    = err
    Scheduler.wakeup (client._co)
  end
  if not _G.js then
    client._ws:on_open    (client._ws.onopen   )
    client._ws:on_close   (client._ws.onclose  )
    client._ws:on_message (client._ws.onmessage)
    client._ws:on_error   (client._ws.onerror  )
  end
  if _G.js then
    client._co = coroutine.running ()
    Scheduler.sleep (-math.huge)
  else
    threadof (client._connect)
  end
end

function Client.__index (client, key)
  return setmetatable ({
    _client = client,
    _keys   = { key },
  }, Operation)
end

function Operation.__index (operation, key)
  local unpack = table.unpack or unpack
  return setmetatable ({
    _client = operation._client,
    _keys = { unpack (operation._keys), key },
  }, Operation)
end

function Operation.__call (operation, parameters, try_only)
  -- Automatic reconnect:
  local client = operation._client
  if client._status ~= "opened" then
    Client.connect (client)
  end
  if client._status ~= "opened" then
    return nil, {
      _ = i18n ["server:unreachable"],
    }
  end
  -- Special case:
  if  type (parameters) == "table"
  and parameters.username and parameters.password then
    client.username = parameters.username
    client.password = parameters.password
    parameters.password = Digest ("{{{username}}}:{{{password}}}" % {
      username = parameters.username,
      password = parameters.password,
    })
  end
  if client._token and not parameters.token then
    parameters.token = client._token
  end
  -- Call:
  for _ = 1, 2 do
    local result
    local function f ()
      local co         = coroutine.running ()
      local identifier = #client._waiting + 1
      client._waiting [identifier] = co
      client._results [identifier] = nil
      client._ws:send (Value.expression {
        identifier = identifier,
        operation  = table.concat (operation._keys, ":"),
        parameters = parameters,
        try_only   = try_only,
      })
      Scheduler.sleep (Configuration.library.timeout._)
      result = client._results [identifier]
      client._waiting [identifier] = nil
      client._results [identifier] = nil
    end
    threadof (f)
    if result == nil then
      return nil, {
        _ = i18n ["server:timeout"],
      }
    elseif not result.success then
      if  result.error
      and result.error._ == "check:error"
      and #result.error.reasons == 1
      and result.error.reasons [1].parameter == "token"
      and result.error.reasons [1]._ == "check:token:invalid"
      and client.username
      and client.password
      then
        local token = client.user.authenticate {
          username = client.username,
          password = client.password,
        }
        if not token then
          return nil, result.error
        end
        client    ._token = token
        parameters.token  = token
      else
        return nil, result.error
      end
    else
      return result.response or true
    end
  end
end

function Library.client (t)
  local client = setmetatable ({
    _results = {},
    _waiting = {},
    _token   = false,
  }, Client)
  client.host     = t.host     or false
  client.port     = t.port     or 80
  client.username = t.username or false
  client.password = t.password or false
  Client.connect (client)
  if client._status == "opened" then
    if  client.username and client.username ~= ""
    and client.password and client.password ~= "" then
      client._token = client.authenticate {
        username = client.username,
        password = client.password,
      }
    end
    return client
  elseif client._status == "closed" then
    return nil, client._err
  else
    assert (false)
  end
end

if _G.js then
  function Library.connect (url)
    local parser   = _G.window.document:createElement "a";
    parser.href    = url;
    return Library.client {
      host     = parser.hostname,
      port     = parser.port,
      username = parser.username,
      password = parser.password,
    }
  end
else
  local Url = require "socket.url"
  function Library.connect (url)
    local parsed = Url.parse (url)
    return Library.client {
      host     = parsed.host,
      port     = parsed.port,
      username = parsed.user,
      password = parsed.password,
    }
  end
end

return Library
