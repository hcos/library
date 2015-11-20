return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Digest        = loader.load "cosy.digest"
  local I18n          = loader.load "cosy.i18n"
  local Json          = loader.load "cosy.json"
  local Value         = loader.load "cosy.value"
  local Scheduler     = loader.load "cosy.scheduler"
  local Coromake      = loader.require "coroutine.make"

  Configuration.load "cosy.library"

  local i18n   = I18n.load "cosy.library"
  i18n._locale = Configuration.locale

  local Library   = {}
  local Client    = {}
  local Operation = {}

  local function threadof (f, ...)
    if Scheduler._running then
      f (...)
    else
      Scheduler.addthread (f, ...)
      Scheduler._running = true
      Scheduler.loop ()
      Scheduler._running = false
    end
  end

  Client.coroutine = Coromake ()

  local JsWs = {}

  function JsWs.new (t)
    return setmetatable ({
      timeout = t.timeout or 5,
    }, JsWs)
  end

  function JsWs.connect (ws, url, protocol)
    ws.ws     = _G.js.new (_G.window.WebSocket, url, protocol)
    ws.co     = coroutine.running ()
    ws.status = "closed"
    ws.ws:on_open    (function ()
      ws.status = "opened"
    end)
    ws.ws:on_close   (function ()
      ws.status = "closed"
    end)
    ws.ws:on_message (function (_, event)
      ws.message = event.data
      Scheduler.wakeup (ws.co)
    end)
    ws.ws:on_error   (function ()
      ws.status = "closed"
    end)
    Scheduler.sleep (ws.timeout)
    if ws.status == "opened" then
      return ws
    else
      return nil, ws.state
    end
  end

  function JsWs:receive ()
    self.message = nil
    self.co      = coroutine.running ()
    Scheduler.sleep (self.timeout)
    return self.message
  end

  function JsWs:send (message)
    self.ws:send (message)
  end

  function JsWs:close ()
    self.ws:close ()
  end

  function Client.connect (client)
    local data = client._data
    local url = "ws://{{{host}}}:{{{port}}}/ws" % {
      host = data.host,
      port = data.port,
    }
    if _G.js then
      client._ws = assert (JsWs.new {
        timeout = Configuration.library.timeout,
      })
    else
      local Websocket = loader.require "websocket"
      client._ws = assert (Websocket.client.copas {
        timeout = Configuration.library.timeout,
      })
    end
    client._ws.status = "closed"
    threadof (function ()
      local ok, err = client._ws:connect (url, "cosy")
      if ok then
        client._ws.status = "opened"
      else
        client._ws.status = "closed"
        client._ws.error  = err
      end
    end)
    if  client._ws.status == "opened"
    and data.identifier and data.identifier ~= ""
    and data.password   and data.password   ~= "" then
      client.user.authenticate {}
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

  function Operation.__call (operation, parameters, try_only, no_redo)
    -- Automatic reconnect:
    local client = operation._client
    local data   = client._data
    if client._ws.status ~= "opened" then
      Client.connect (client)
    end
    if client._ws.status ~= "opened" then
      return nil, i18n {
        _ = i18n ["server:unreachable"],
      }
    end
    local done = false
    local function receive_messages ()
      while not done do
        local message = client._ws:receive ()
        if message then
          message = Value.decode (message)
          local identifier = message.identifier
          if identifier then
            local results = client._results [identifier]
            assert (results)
            results [#results+1] = message
            if coroutine.status (client._waiting [identifier]) == "suspended" then
              Scheduler.wakeup (client._waiting [identifier])
              Scheduler.sleep (0)
            end
          end
        end
      end
    end
    -- Call special cases:
    local result, err
    threadof (function ()
      if data.token and parameters and not parameters.authentication then
        parameters.authentication = data.token
      end
      local identifier = #client._waiting + 1
      local operator   = table.concat (operation._keys, ":")
      local wrapper    = Client.methods [operator]
      local wrapperco  = wrapper and Client.coroutine.create (wrapper) or nil
      client._waiting [identifier] = Scheduler.running
                                 and Scheduler.running ()
                                  or coroutine.running ()
      client._results [identifier] = {}
      if wrapperco then
        Client.coroutine.resume (wrapperco, operation, parameters, try_only)
      end
      client._ws:send (Value.expression {
        identifier = identifier,
        operation  = operator,
        parameters = parameters,
        try_only   = try_only,
      })
      Scheduler.addthread (receive_messages)
      Scheduler.sleep (Configuration.library.timeout)
      local results = client._results [identifier]
      if results [1] == nil then
        result, err = nil, {
          _ = i18n ["server:timeout"],
        }
        client._waiting [identifier] = nil
        client._results [identifier] = nil
      elseif results [1].iterator then
        local coroutine = Coromake ()
        result = results [1]
        table.remove (results, 1)
        result.iterator = coroutine.wrap (function ()
          repeat
            local subresult = results [1]
            if subresult == nil then
              Scheduler.sleep (Configuration.library.timeout)
            else
              if subresult.finished then
                client._waiting [identifier] = nil
                client._results [identifier] = nil
              end
              coroutine.yield (subresult)
              table.remove (results, 1)
            end
          until subresult and subresult.finished
        end)
      else
        result = results [1]
        client._waiting [identifier] = nil
        client._results [identifier] = nil
      end
      if result and result.success then
        if wrapperco and not try_only then
          Client.coroutine.resume (wrapperco, result)
        end
        if result.iterator then
          local iterator = result.iterator
          result, err = function ()
            local r
            threadof (function ()
              client._waiting [identifier] = Scheduler.running ()
              r = iterator ()
            end)
            if r.success then
              return r.response
            else
              error (r.error)
            end
          end, nil
        else
          result, err = result.response or true, nil
        end
      elseif operator == "user:authenticate" then
        result, err = nil, result.error
      elseif  result
      and     result.error
      and (   result.error._ == "user:authenticate:failure"
          or  result.error._ == "check:error"
          and result.error.reasons
          and #result.error.reasons == 1
          and result.error.reasons [1].key == "authentication"
          )
      then
        if (data.identifier and data.hashed and not client.user.authenticate {})
        or not data.identifier
        or not data.hashed
        then
          data.identifier           = nil
          data.hashed               = nil
          data.token                = nil
          parameters.authentication = nil
        end
        if not no_redo then
          result, err = operation (parameters, try_only, true)
        else
          result, err = nil, result.error
        end
      elseif result then
        result, err = nil, result.error
      end
      done = true
    end)
    return result, err
  end

  Client.methods = {}

  Client.methods ["user:create"] = function (operation, parameters)
    local client        = operation._client
    local data          = client._data
    data.identifier     = nil
    data.hashed         = nil
    data.token          = nil
    data.token          = nil
    parameters.password = Digest (parameters.password)
    local result        = Client.coroutine.yield ()
    if result.success then
      data.identifier = parameters.identifier
      data.hashed     = parameters.password
      data.token      = result.response.authentication
      client.user.update {
        authentication = data.token,
        position       = true,
      }
    end
  end

  Client.methods ["user:authenticate"] = function (operation, parameters)
    local client = operation._client
    local data   = client._data
    data.token   = nil
    parameters.user = parameters.user or data.identifier
    if parameters.password then
      parameters.password = Digest (parameters.password)
    elseif data.hashed then
      parameters.password = data.hashed
    end
    local result = Client.coroutine.yield ()
    if result.success then
      data.identifier = parameters.user
      data.hashed     = parameters.password
      data.token      = result.response.authentication
    end
  end

  Client.methods ["user:delete"] = function (operation)
    local client    = operation._client
    local data      = client._data
    data.identifier = nil
    data.hashed     = nil
    data.token      = nil
    Client.coroutine.yield ()
  end

  Client.methods ["user:update"] = function (operation, parameters)
    local client = operation._client
    local data   = client._data
    if parameters.password then
      parameters.password = Digest (parameters.password)
    end
    if  type (parameters.position) == "table"
    and parameters.position.longitude == ""
    and parameters.position.latitude  == "" then
      -- FIXME: should not be wrapped
      coroutine.wrap (function ()
        local url = data.url .. "/ext/maps?address={{{country}}},{{{city}}}" % {
          country = parameters.position.country,
          city    = parameters.position.city,
        }
        local response, status = loader.request (url)
        if status == 200 then
          local coordinate   = Json.decode (response)
          local position     = parameters.position
          position.latitude  = coordinate.results [1].geometry.location.lat
          position.longitude = coordinate.results [1].geometry.location.lng
        end
      end) ()
    end
    local result = Client.coroutine.yield ()
    if result.success and parameters.password then
      data.hashed = parameters.password
    end
  end

  Client.methods ["user:recover"] = Client.methods ["user:update"]

  Client.methods ["server:filter"] = function (_, parameters)
    if type (parameters.iterator) == "function" then
      parameters.iterator = string.dump (parameters.iterator)
    end
    Client.coroutine.yield ()
  end

  function Library.client (t)
    local client = setmetatable ({
      _status  = false,
      _error   = false,
      _ws      = false,
      _co      = coroutine.running (),
      _results = {},
      _waiting = {},
      _data    = {},
    }, Client)
    client._data.url        = t.url        or false
    client._data.host       = t.host       or false
    client._data.port       = t.port       or 80
    client._data.identifier = t.identifier or false
    client._data.password   = t.password   or false
    client._data.hashed     = false
    client._data.token      = false
    Client.connect (client)
    if client._ws.status == "opened" then
      return client
    elseif client._ws.status == "closed" then
      return nil, client._ws.error
    else
      assert (false)
    end
  end

  if _G.js then
    function Library.connect (url)
      local parser   = _G.window.document:createElement "a";
      parser.href    = url;
      return Library.client {
        url        = url,
        host       = parser.hostname,
        port       = parser.port,
        identifier = parser.username,
        password   = parser.password,
      }
    end
  else
    local Url = loader.require "socket.url"
    function Library.connect (url)
      local parsed = Url.parse (url)
      return Library.client {
        url        = url,
        host       = parsed.host,
        port       = parsed.port,
        identifier = parsed.user,
        password   = parsed.password,
      }
    end
  end

  return Library

end
