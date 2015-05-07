local loader  = require "cosy.loader"

local Server = {}

function Server.get (http)
  if  http.request.method == "POST"
  and http.request.headers.user_agent:match "GitHub%-Hookshot/"
  and http.request.headers.x_github_event == "push"
  and loader.configuration.debug.update._ then
    loader.logger.info {
      _ = "github:push",
    }
    local temporary = os.tmpname ()
    local file      = io.open (temporary, "w")
    file:write [[
#! /usr/bin/env bash
git pull --quiet --force
luarocks install --force --only-deps cosyverif
for rock in $(luarocks list --outdated --porcelain | cut -f 1)
do
  luarocks install --force ${rock}
done
rm --force $0
]]
    file:close ()
    os.execute ("bash " .. temporary .. " &")
    http.response.status  = 200
    http.response.message = "OK"
    return
  elseif http.request.headers ["upgrade"] == "websocket" then
    http () -- send response
    return Server.wsloop (http)
  elseif http.request.method ~= "GET" then
    http.response.status  = 405
    http.response.message = "Method Not Allowed"
    return
  end
  assert (http.request.method == "GET")
  if  http.request.method == "GET"
  and http.request.path:sub (-1) == "/" then
      http.request.path = http.request.path .. "index.html"
  end
  local lua_module = http.request.path:match "/lua/(.*)"
  if lua_module then
    lua_module = lua_module:gsub ("/", ".")
    local path = package.searchpath (lua_module, package.path)
    if path then
      local file = io.open (path, "r")
      http.response.status  = 200
      http.response.message = "OK"
      http.response.body    = file:read "*all"
      file:close ()
      return
    end
  end
  local mimetypes = loader "mimetypes"
  local file = io.open ("%{root}/%{path}" % {
    root = loader.configuration.www.root._,
    path = http.request.path
  })
  if file then
    http.response.status  = 200
    http.response.message = "OK"
    http.response.body    = file:read "*all"
    http.response.headers.content_type = mimetypes.guess (http.request.path)
    file:close ()
    return
  end
  http.response.status  = 404
  http.response.message = "Not Found"
end

function Server.request (message)
  local i18n = loader.i18n
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

function Server.www_dependencies ()
  local scheduler = loader.scheduler
  scheduler.blocking (false)
  local directories = {
    loader.configuration.www.root._,
    loader.configuration.www.root._ .. "/css",
    loader.configuration.www.root._ .. "/font",
    loader.configuration.www.root._ .. "/html",
    loader.configuration.www.root._ .. "/js",
  }
  local continue = true
  local lfs = loader.hotswap "lfs"
  for i = 1, #directories do
    local directory  = directories [i]
    local attributes = lfs.attributes (directory)
    if attributes and attributes.mode ~= "directory" then
      loader.logger.error {
        _         = "directory:not-directory",
        directory = directory,
        mode      = attributes.mode,
      }
      return
    end
    if not attributes then
      local ok, err = lfs.mkdir (directory)
      if ok then
        loader.logger.info {
          _         = "directory:created",
          directory = directory,
        }
      else
        loader.logger.error {
          _         = "directory:not-created",
          directory = directory,
          reason    = err,
        }
        continue = false
      end
    end
  end
  while continue do
    local request = (loader.hotswap "copas.http").request
    for target in pairs (loader.configuration.dependencies) do
      local source  = loader.configuration.dependencies [target]
      local url     = tostring (source._)
      if url:match "^http" then
        local content, status = request (url)
        if math.floor (status / 100) == 2 then
          local file = io.open (loader.configuration.www.root._ .. "/" .. target, "w")
          file:write (content)
          file:close ()
          loader.logger.info {
            _      = "dependency:success",
            source = source,
            target = target,
          }
        else
          loader.logger.warning {
            _      = "dependency:failure",
            source = source,
            target = target,
          }
        end
      end
    end
    scheduler.sleep (loader.configuration.dependencies.expiration._)
  end
end

do
  local scheduler     = loader.scheduler
  local configuration = loader.configuration
  local host          = configuration.server.host._
  local port          = configuration.server.port._
  local skt           = (loader.hotswap "socket").bind (host, port)
  scheduler.addthread (Server.www_dependencies)
  scheduler.addserver (skt, function (socket)
    local Http = loader.hotswap "httpserver"
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
  loader.logger.info {
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