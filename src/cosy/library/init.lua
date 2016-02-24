return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Digest        = loader.load "cosy.digest"
  local I18n          = loader.load "cosy.i18n"
  local Value         = loader.load "cosy.value"
  local Coromake      = loader.require "coroutine.make"

  Configuration.load "cosy.library"

  local i18n   = I18n.load "cosy.library"
  i18n._locale = Configuration.locale

  local Library   = {}
  local Client    = {}
  local Operation = {}

  Library.info = setmetatable ({}, {
    __mode = "k",
  })

  Client.coroutine = Coromake ()

  local Status = {
    opened = {},
    closed = {},
  }

  local JsWs = {}

  JsWs.__index = JsWs

  function JsWs.new (t)
    return setmetatable ({
      timeout = t.timeout or 5,
    }, JsWs)
  end

  function JsWs.connect (websocket, url, protocol, second_try)
    websocket.ws     = loader.js.new (loader.js.global.WebSocket, url, protocol)
    websocket.co     = loader.scheduler.running ()
    websocket.status = Status.closed
    websocket.ws.onopen = function ()
      websocket.status = Status.opened
      loader.scheduler.wakeup (websocket.co)
    end
    websocket.ws.onclose = function ()
      websocket.status = Status.closed
      loader.scheduler.wakeup (websocket.co)
    end
    websocket.ws.onmessage = function (_, event)
      websocket.message = event.data
      loader.scheduler.wakeup (websocket.co)
    end
    websocket.ws.onerror = function ()
      websocket.status = Status.closed
      loader.scheduler.wakeup (websocket.co)
    end
    loader.scheduler.sleep (websocket.timeout)
    if not second_try and websocket.status == Status.closed then
      websocket.ws:close ()
      return JsWs.connect (websocket, url, protocol, true)
    elseif websocket.status == Status.opened then
      return websocket
    else
      return nil, websocket.reason
    end
  end

  function JsWs.receive (websocket)
    websocket.message = nil
    websocket.co      = loader.scheduler.running ()
    loader.scheduler.sleep (websocket.timeout)
    return websocket.message
  end

  function JsWs.send (websocket, message)
    websocket.ws:send (message)
  end

  function JsWs.close (websocket)
    websocket.ws:close ()
  end

  local Receiver = {}

  function Receiver.new (client)
    return setmetatable ({
      client  = setmetatable ({
        id = client,
      }, {
        __mode = "v",
      }),
      waiting = {},
    }, Receiver)
  end

  function Receiver.step (receiver)
    local info    = Library.info [receiver.client.id]
    local message = info.websocket:receive ()
    if message then
      message = Value.decode (message)
      local identifier = message.identifier
      local results    = info.results [identifier]
      if results then
        results [#results+1] = message
        for co in pairs (receiver.waiting) do
          loader.scheduler.wakeup (co)
        end
      end
    end
  end

  function Receiver.loop (receiver)
    return loader.scheduler.addthread (function ()
      while true do
        if not receiver.client.id then
          break
        end
        local info = Library.info [receiver.client.id]
        if info.websocket.status ~= Status.opened then
          break
        end
        Receiver.step (receiver)
      end
    end)
  end

  function Receiver.__call (receiver, identifier)
    local info = Library.info [receiver.client.id]
    if not info then
      return
    end
    local results = info.results [identifier]
    if info.synchronous then
      repeat
        Receiver.step (receiver)
      until info.websocket.status ~= Status.opened or results [1]
    elseif info.asynchronous then
      receiver.waiting [loader.scheduler.running ()] = true
      repeat
        loader.scheduler.sleep (-math.huge)
      until info.websocket.status ~= Status.opened or results [1]
      receiver.waiting [loader.scheduler.running ()] = nil
    end
    return results [1]
  end

  function Client.new (t)
    t.url = t.url
        and t.url:gsub ("^%s*(.-)/*%s*$", "%1")
         or t.url
    local client = setmetatable ({}, Client)
    Library.info [client] = {
      data           = t.data         or {},
      url            = t.url          or false,
      host           = t.host         or false,
      port           = t.port         or 80,
      identifier     = t.identifier   or false,
      password       = t.password     or false,
      synchronous    = t.synchronous  or false,
      asynchronous   = t.asynchronous or false,
      hashed         = false,
      authentication = false,
      websocket      = false,
      results        = {},
      receiver       = Receiver.new (client),
    }
    local ok, err = Client.connect (client)
    if ok then
      return client
    else
      return nil, err
    end
  end

  function Client.connect (client)
    local info = Library.info [client]
    local url  = "ws://{{{host}}}:{{{port}}}/ws" % {
      host = info.host,
      port = info.port,
    }
    if loader.js then
      info.websocket = JsWs.new {
        timeout = Configuration.library.timeout,
      }
    elseif client.synchronous then
      local Websocket = loader.require "websocket"
      info.websocket = Websocket.client.sync {
        timeout = Configuration.library.timeout,
      }
    elseif client.asynchronous then
      local Websocket = loader.require "websocket"
      info.websocket = Websocket.client.copas {
        timeout = Configuration.library.timeout,
      }
    end
    info.websocket.status = Status.closed
    if not info.websocket:connect (url, "cosy") then
      return nil
    end
    info.websocket.status = Status.opened
    if client.asynchronous then
      info.receiver.co = Receiver.loop (info.receiver)
    end
    if  info.identifier and info.identifier ~= ""
    and info.password   and info.password   ~= "" then
      client.user.authenticate {}
    end
    return true
  end

  function Client.__index (client, key)
    local result = setmetatable ({}, Operation)
    Library.info [result] = {
      client = client,
      keys   = { key },
    }
    return result
  end

  function Operation.__index (operation, key)
    local info   = Library.info [operation]
    local result = setmetatable ({}, Operation)
    Library.info [result] = {
      client = info.client,
      keys   = { table.unpack (info.keys), key },
    }
    return result
  end

  local Iterator = setmetatable ({}, {
    __tostring = function () return "Iterator" end,
  })

  function Iterator.new (t)
    local info    = Library.info [t.client]
    local results = info.results [t.identifier]
    local result  = results [1]
    table.remove (results, 1)
    return setmetatable ({
      client     = t.client,
      identifier = t.identifier,
      token      = result.token,
    }, Iterator)
  end

  function Iterator.__call (iterator)
    local info    = Library.info [iterator.client]
    local results = info.results [iterator.identifier]
    local result  = info.receiver (iterator.identifier)
    if result == nil then
      info.results [iterator.identifier] = nil
      error {
        _ = i18n ["server:timeout"],
      }
    elseif result.finished then
      info.results [iterator.identifier] = nil
      iterator.identifier = -math.huge
      return nil
    else
      table.remove (results, 1)
      if result.success then
        return result.response
      else
        return nil, result.error
      end
    end
  end

  function Iterator.__gc (iterator)
    local info = Library.info [iterator.client]
    if loader.js then
      loader.scheduler.addthread (function ()
        iterator.client.server.cancel {
          filter = iterator.token,
        }
      end)
      if not loader.scheduler.running () then
        loader.scheduler.loop ()
      end
    else
      iterator.client.server.cancel {
        filter = iterator.token,
      }
    end
    info.results [iterator.identifier] = nil
  end

  function Operation.__call (operation, parameters, options)
    parameters = parameters or {}
    options    = options    or {}
    local path     = Library.info [operation]
    local client   = path.client
    local info     = Library.info [client]
    local password = parameters.password
    -- Automatic reconnect:
    if info.websocket.status ~= Status.opened then
      if not Client.connect (client) then
        return nil, i18n {
          _      = i18n ["server:unreachable"],
        }
      end
    end
    -- Call special cases:
    if not parameters.authentication then
      parameters.authentication = info.authentication
                               or info.data.authentication
    end
    local identifier = #info.results+1
    info.results [identifier] = {}
    path.coroutine   = Coromake ()
    local operator   = table.concat (path.keys, ":")
    local wrapper    = Client.methods [operator]
    local wrapperco  = wrapper and path.coroutine.create (wrapper) or nil
    if wrapperco then
      path.coroutine.resume (wrapperco, operation, parameters, options)
    end
    -- Send request:
    info.websocket:send (Value.expression {
      identifier = identifier,
      operation  = operator,
      parameters = parameters,
      try_only   = options.try_only,
    })
    local result = info.receiver (identifier)
    if not result then
      info.results [identifier] = nil
      return nil, {
        _ = i18n ["server:timeout"],
      }
    end
    -- Handle results:
    if result.iterator then
      return Iterator.new {
        client     = client,
        identifier = result.identifier
      }
    end
    -- Special case: password size
    if password and #password < Configuration.library.password then
      local reason = i18n {
        _    = i18n ["password:too-weak"],
        key  = "password",
        size = Configuration.library.password,
      }
      if result.success then
        result.success = false
        result.error   = {
          reasons = { reason },
        }
      else
        result.error.reasons [#result.error.reasons+1] = reason
      end
    end
    info.results [identifier] = nil
    local retry = Client.methods.fix_authentication (operation, parameters, result)
    if retry and not info.retry then
      info.retry = true
      return operation (parameters, options)
    end
    if wrapperco then
      path.coroutine.resume (wrapperco, result)
    end
    if result.success then
      return result.response
    else
      return nil, result.error
    end
  end

  Client.methods = {}

  Client.methods.fix_authentication = function (operation, parameters, result)
    local path = Library.info [operation]
    local info = Library.info [path.client]
    if result.success then
      return false
    end
    if result.error and result.error.reasons then
      for _, reason in ipairs (result.error.reasons) do
        if  reason._   == "check:token:invalid"
        and reason.key == "authentication" then
          parameters.authentication = nil
          info.authentication       = nil
          info.data.authentication  = nil
          return true
        end
      end
    end
    return false
  end

  Client.methods ["user:create"] = function (operation, parameters)
    local path = Library.info [operation]
    local info = Library.info [path.client]
    info.identifier     = nil
    info.hashed         = nil
    info.authentication = nil
    parameters.password = Digest (parameters.password)
    local result = path.coroutine.yield ()
    if result.success then
      info.identifier          = parameters.identifier
      info.hashed              = parameters.password
      info.authentication      = result.response.authentication
      info.data.authentication = result.response.authentication
    end
  end

  Client.methods ["user:authenticate"] = function (operation, parameters)
    local path = Library.info [operation]
    local info = Library.info [path.client]
    info.authentication = nil
    parameters.user     = parameters.user or info.identifier
    if parameters.password then
      parameters.password = Digest (parameters.password)
    elseif info.hashed then
      parameters.password = info.hashed
    end
    local result = path.coroutine.yield ()
    if result.success then
      info.identifier          = parameters.user
      info.hashed              = parameters.password
      info.authentication      = result.response.authentication
      info.data.authentication = result.response.authentication
    end
  end

  Client.methods ["user:delete"] = function (operation)
    local path = Library.info [operation]
    local info = Library.info [path.client]
    info.identifier          = nil
    info.hashed              = nil
    info.authentication      = nil
    info.data.authentication = nil
    path.coroutine.yield ()
  end

  Client.methods ["user:update"] = function (operation, parameters)
    local path = Library.info [operation]
    local info = Library.info [path.client]
    if parameters.password then
      parameters.password = Digest (parameters.password)
    end
    local result = path.coroutine.yield ()
    if result.success and parameters.password then
      info.hashed = parameters.password
    end
  end

  Client.methods ["user:recover"] = Client.methods ["user:update"]

  Client.methods ["server:filter"] = function (operation, parameters)
    local path = Library.info [operation]
    if type (parameters.iterator) == "function" then
      parameters.iterator = string.dump (parameters.iterator)
    end
    path.coroutine.yield ()
  end

  function Library.connect (url, data)
    local parameters
    if loader.js then
      local parser = loader.js.global.document:createElement "a";
      parser.href  = url;
      parameters   = {
        url        = url,
        host       = parser.hostname,
        port       = parser.port,
        identifier = parser.username,
        password   = parser.password,
        data       = data,
      }
    else
      local Url    = loader.require "socket.url"
      local parsed = Url.parse (url)
      parameters   = {
        url        = url,
        host       = parsed.host,
        port       = parsed.port,
        identifier = parsed.user,
        password   = parsed.password,
        data       = data,
      }
    end
    if loader.scheduler.running () then
      parameters.asynchronous = true
    else
      parameters.synchronous  = true
    end
    return Client.new (parameters)
  end

  return Library

end
