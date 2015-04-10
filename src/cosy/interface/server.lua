local Configuration = require "cosy.configuration"
local Platform      = require "cosy.platform"
local Methods       = require "cosy.methods"
local Http          = require "cosy.http"
local Socket        = require "socket"
local Copas         = require "copas.ev"
Copas:make_default ()

local function get (context)
  if context.request.method ~= "GET" then
    context.response.status  = 405
    context.response.message = "Method Not Allowed"
    return
  elseif context.request.headers ["upgrade"] == "websocket" then
    return
  elseif context.request.method == "GET" then
    if context.request.path:sub (-1) == "/" then
      context.request.path = context.request.path .. "index.html"
    end
    for path in package.path:gmatch "([^;]+)" do
      if path:sub (-5) == "?.lua" then
        path = path:sub (1, #path - 5) .. context.request.path
        local file = io.open (path, "r")
        if file then
          context.response.status  = 200
          context.response.message = "OK"
          context.response.body = file:read "*all"
          file:close ()
          return
        end
      end
    end
    context.response.status  = 404
    context.response.message = "Not Found"
    return
  else
    context.response.status  = 500
    context.response.message = "Internal Server Error"
  end
end

local function translate (x)
  x.locale = x.locale or Configuration.locale._
  for _, v in pairs (x) do
    if type (v) == "table" and not getmetatable (v) then
      local vl  = v.locale
      v.locale  = x.locale
      v.message = translate (v)
      v.locale  = vl
    end
  end
  if x._ then
    x.message = Platform.i18n.translate (x._, x)
  end
  return x
end

local function request (message)
  local decoded, request = Platform.table.decode (message)
  if not decoded then
    return Platform.table.encode (translate {
      success = false,
      error   = {
        _      = "rpc:format",
        reason = message,
      },
    })
  end
  local identifier = request.identifier
  local operation  = request.operation
  local parameters = request.parameters
  local method     = Methods [operation]
  if not method then
    return Platform.table.encode (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _      = "rpc:no-operation",
        reason = operation,
      },
    })
  end
  local called, result = pcall (method, parameters or {})
  if not called then
    return Platform.table.encode (translate {
      identifier = identifier,
      success    = false,
      error      = result,
    })
  end
  return Platform.table.encode (translate {
    identifier = identifier,
    success    = true,
    response   = result,
  })
end

local function wsloop (context)
  while context.websocket.client.state ~= "CLOSED" do
    local message = context.websocket.client:receive ()
    if message then
      local result = request (message)
      if result then
        context.websocket.client:send (result)
      end
    else
      context.websocket.client:close ()
    end
  end
end

Platform:register ("email", function ()
  Platform.email = {}
  Platform.email.last_sent = {}
  Platform.email.send = function (t)
    Platform.email.last_sent [t.to.email] = t
  end
end)

do
  local host  = Configuration.server.host._
  local port  = Configuration.server.port._
  local skt   = Socket.bind (host, port)
  Copas.addserver (skt, function (socket)
    local handler = Http
    local context = {
      socket    = socket,
      http      = {
        handler = get,
      },
      websocket = {
        handler   = wsloop,
        protocols = { "cosy" },
      },
    }
    repeat
      handler = handler (context)
    until not handler
  end)
  Platform.logger.debug {
    _    = "server:listening",
    host = host,
    port = port,
  }
--  local profiler = require "ProFi"
--  profiler:start ()
  Copas.loop ()
--  profiler:stop ()
--  profiler:writeReport "profiler.txt"
end