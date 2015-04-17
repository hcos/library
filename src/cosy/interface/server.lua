                      require "compat53"
local Configuration = require "cosy.configuration"
local Platform      = require "cosy.platform"
local Socket        = require "socket"
local Copas         = require "copas.ev"
local hotswap       = require "hotswap"
Copas:make_default ()

local Server = {}

function Server.get (http)
  if http.request.method ~= "GET" then
    http.response.status  = 405
    http.response.message = "Method Not Allowed"
  elseif http.request.headers ["upgrade"] == "websocket" then
    http () -- send response
    http.socket:send "\r\n"
    return Server.wsloop (http)
  elseif http.request.method == "GET" then
    if http.request.path:sub (-1) == "/" then
      http.request.path = http.request.path .. "index.html"
    end
    if http.request.path:sub (-9) == "cosy.conf" then
      http.response.status  = 403
      http.response.message = "Forbidden"
      http.response.body    = "Nice try ;-)\n"
    else
      for path in package.path:gmatch "([^;]+)" do
        if path:sub (-5) == "?.lua" then
          path = path:sub (1, #path - 5) .. http.request.path
          local file = io.open (path, "r")
          if file then
            http.response.status  = 200
            http.response.message = "OK"
            http.response.body    = file:read "*all"
            file:close ()
            return
          end
        end
      end
    end
    http.response.status  = 404
    http.response.message = "Not Found"
  else
    http.response.status  = 500
    http.response.message = "Internal Server Error"
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

function Server.request (message)
  local decoded, request = pcall (Platform.value.decode, message)
  if not decoded or type (request) ~= "table" then
    return Platform.value.expression (translate {
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
  local Methods    = hotswap "cosy.methods"
  local method     = Methods [operation]
  if not method then
    return Platform.value.expression (translate {
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
    return Platform.value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = result,
    })
  end
  return Platform.value.expression (translate {
    identifier = identifier,
    success    = true,
    response   = result,
  })
end

function Server.wsloop (http)
  while http.websocket.client.state ~= "CLOSED" do
    local message = http.websocket.client:receive ()
    if message then
      local result = Server.request (message)
      if result then
        http.websocket.client:send (result)
      end
    else
      http.websocket.client:close ()
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
  local host = Configuration.server.host._
  local port = Configuration.server.port._
  local skt  = Socket.bind (host, port)
  Copas.addserver (skt, function (socket)
    local Http = hotswap "httpserver"
    local http = Http.new {
      socket    = socket,
      websocket = {
        protocols = { "cosy" },
      },
    }
    pcall (function ()
      repeat
        http ()
        Server.get (http)
        http ()
      until true
    end)
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