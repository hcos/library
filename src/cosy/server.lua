local loader  = require "cosy.loader"
local hotswap = loader.hotswap

local Server = {}

function Server.get (http)
  if  http.request.method == "POST"
  and http.request.headers.user_agent:match "GitHub-Hookshot/"
  and http.request.headers.x_github_event == "push"
  and loader.configuration.debug.update then
    os.execute "git pull --quiet --force"
  elseif http.request.headers ["upgrade"] == "websocket" then
    http () -- send response
    http.socket:send "\r\n"
    return Server.wsloop (http)
  elseif http.request.method ~= "GET" then
    http.response.status  = 405
    http.response.message = "Method Not Allowed"
  end
  assert (http.request.method == "GET")
  if  http.request.method == "GET"
  and http.request.path == "/" then
      http.request.path = http.request.path .. "index.html"
  end
  local lua_module = http.request.path:match "lua:(.*)"
  if lua_module then
    local path = package.searchpath (http.request.path)
    if path then
      local file = io.open (path, "r")
      http.response.status  = 200
      http.response.message = "OK"
      http.response.body    = file:read "*all"
      file:close ()
      return
    end
  end
  local file = io.open ("%{root}/%{path}" % {
    root = loader.configuration.www.root._,
    path = http.request.path
  })
  if file then
    http.response.status  = 200
    http.response.message = "OK"
    http.response.body    = file:read "*all"
    file:close ()
    return
  end
  http.response.status  = 404
  http.response.message = "Not Found"
end

function Server.request (message)
  local loader = hotswap "cosy.loader"
  local i18n   = loader.i18n
  local function translate (x)
    i18n (x)
    return x
  end
  local decoded, request = pcall (loader.value.decode, message)
  if not decoded or type (request) ~= "table" then
    return loader.value.expression (translate {
      success = false,
      error   = {
        _      = "rpc:invalid",
        reason = message,
      },
    })
  end
  local identifier = request.identifier
  local operation  = request.operation
  local parameters = request.parameters
  local Methods    = loader.methods
  local method     = Methods [operation]
  if not method then
    return loader.value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _      = "rpc:no-operation",
        reason = operation,
      },
    })
  end
  local result, err = method (parameters or {})
  if not result then
    loader.logger.warning ("error: " .. loader.value.expression (err))
    loader.logger.warning (debug.traceback())
    return loader.value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = err,
    })
  end
  return loader.value.expression (translate {
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

do
  local socket        = hotswap "socket"
  local scheduler     = loader.scheduler
  local configuration = loader.configuration
  local host = configuration.server.host._
  local port = configuration.server.port._
  local skt  = socket.bind (host, port)
  scheduler.addserver (skt, function (socket)
    local Http = hotswap "httpserver"
    local http = Http.new {
      hotswap   = hotswap,
      socket    = socket,
      websocket = {
        protocols = { "cosy" },
      },
    }
    pcall (function ()
      repeat
        http ()
        Server.get (http)
        local continue = http ()
      until not continue
    end)
  end)
  loader.logger.debug {
    _    = "server:listening",
    host = host,
    port = port,
  }
--  local profiler = require "ProFi"
--  profiler:start ()
  scheduler.loop ()
--  profiler:stop ()
--  profiler:writeReport "profiler.txt"
end