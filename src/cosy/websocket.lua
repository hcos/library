local Configuration = require "cosy.configuration" .whole
local Platform      = require "cosy.platform"
local Methods       = require "cosy.methods"

local LuaRpc = {}

function LuaRpc.message (message)
  local ok, res = Platform.table.decode (message)
  if not ok then
    return Platform.table.encode ({
      version = "2.0",
      id      = nil,
      error   = {
        code    = -32700,
        message = "Parse error",
        data    = res,
      },
    })
  end
  local results = {}
  if #res == 0 then
    results [#results+1] = LuaRpc.request (res)
  else
    for i = 1, #res do
      results [#results+1] = LuaRpc.request (res [i])
      if res [i].id == nil then
        results [#results] = nil
      end
    end
  end
  if #results == 0 then
    return
  elseif #results == 1 then
    return Platform.table.encode (results [1])
  else
    return Platform.table.encode (results)
  end
end

function LuaRpc.request (request)
  if request.version ~= "2.0"
  or type (request.method) ~= "string"
  then
    return {
      LuaRpc = "2.0",
      id      = request.id,
      error   = {
        code    = -32600,
        message = "Invalid Request",
      },
    }
  end
  local method = Methods [request.method:gsub ("-", "_")]
  if not method then
    return {
      version = "2.0",
      id      = request.id,
      error   = {
        code    = -32601,
        message = "Method not found",
      },
    }
  end
  local ok, result = pcall (method, request.params.token, request.params.request)
  if  not ok
  and type (result) == "table" and result._ == "check:error" then
    return {
      version = "2.0",
      id      = request.id,
      error   = {
        code    = -32602,
        message = "Invalid params",
        data    = result,
      },
    }
  end
  if not ok then
    return {
      version = "2.0",
      id      = request.id,
      error   = {
        code    = -32603,
        message = "Internal error",
        data    = result,
      },
    }
  end
  if request.id then
    return {
      version = "2.0",
      id      = request.id,
      result  = result,
    }
  end
end



local copas     = require "copas"
local websocket = require "websocket"

Platform:register ("email", function ()
  Platform.email = {}
  Platform.email.last_sent = {}
  Platform.email.send = function (t)
    Platform.email.last_sent [t.to.email] = t
  end
end)

websocket.server.copas.listen {
  interface = Configuration.server.host._,
  port      = Configuration.server.port._,
  protocols = {
    cosy = function (client)
      while true do
        local message = client:receive ()
        if message then
          local result = LuaRpc.message (message)
          if result then
            client:send (result)
          end
        else
          client:close ()
          return
        end
      end
    end,
  },
  default = function (client)
    client:send "'cosy' is the only supported protocol"
    client:close ()
  end
}

copas.loop ()