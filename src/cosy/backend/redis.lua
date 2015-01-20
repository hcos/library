local Backend = {}

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
local ignore        = require "cosy.util.ignore"
local Email         = require "cosy.util.email"

Backend.pool = {}

Platform.scheduler:addthread (function ()
  local socket    = require "socket"
  local coroutine = require "coroutine.make" ()
  local host      = Configuration.redis.host
  local port      = Configuration.redis.port
  local database  = Configuration.redis.database
  local size      = Configuration.redis.size
  for _ = 1, size do
    local skt    = Platform.scheduler:wrap (socket.tcp ()):connect (host, port)
    local client = Platform.redis.connect {
      socket    = skt,
      coroutine = coroutine,
    }
    client:select (database)
    Backend.pool [#(Backend.pool) + 1] = client
  end
end)

function Backend.pool.using (f)
  local pool = Backend.pool
  while #pool == 0 do
    Platform.scheduler:pass ()
  end
  local client     = pool [#pool]
  pool [#pool]     = nil
  local ok, result = pcall (f, client)
  pool [#pool + 1] = client
  if ok then
    return result
  else
    error (result)
  end
end

function Backend.pool.transaction (keys, f)
  local pool = Backend.pool
  while #pool == 0 do
    Platform.scheduler:pass ()
  end
  local client     = pool [#pool]
  pool [#pool]     = nil
  local ok, result = pcall (client.transaction, client, {
    watch = keys,
    cas   = true,
    retry = 5,
  }, f)
  pool [#pool + 1] = client
  if ok then
    return result
  else
    error (result)
  end
end

-- Data representation:
-- Every resource is a hash containing:
-- * metadata: all public metadata
-- * secrets: all secrets metadata (password, keys, ...)
-- * contents: all subresources

Backend.__index = Backend

Backend.coroutine = require "coroutine.make" ()

local Parameters = {}

Parameters.username = {}
Parameters.username.type = "string"
Parameters.username.hint = "username"
Parameters.username.checks = {}
Parameters.username.checks ["a username must be a string"] = function (t)
  return type (t.username) == "string"
end
Parameters.username.checks ["a username must contain at least one character"] = function (t)
  return #(t.username) > 0
end
Parameters.username.checks ["a username must be composed only of alphanumeric characters"] = function (t)
  return t.username:find "^%w+$"
end

Parameters.password = {}
Parameters.password.type = "string"
Parameters.password.hint = "password"

Parameters.email = {}
Parameters.email.type = "string"
Parameters.email.hint = "youremail@domain.org"
Parameters.email.checks = {}
Parameters.email.checks ["an email must comply to the standard format"] = function (t)
  t.email = t.email:trim ()
  local pattern = "^[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?>"
  return t.email:find (pattern)
end

local function check (parameters, t)
  local reasons = {}
  for key in pairs (t) do
    for reason, f in pairs (parameters [key].checks or {}) do
      if not f (t) then
        reasons [#reasons + 1] = reason
      end
    end
  end
  if #reasons ~= 0 then
    error (reasons)
  end
end

function Backend.information (session, t, interactive)
  ignore (session)
  ignore (t)
  ignore (interactive)
  return Backend.coroutine.wrap (function ()
    return {
      url = "http://${host}:${port}/" % {
        host = Configuration.server.host,
        port = Configuration.server.port,
      }
      -- TODO: fill with public server information
    }
  end) ()
end

function Backend.authenticate (session, t, interactive)
  ignore (interactive)
  return Backend.coroutine.wrap (function ()
    local username = t.username
    local id = "/${username}" % {
      username = username,
    }
    session.username = nil
    Backend.pool.using (function (redis)
      local secrets  = redis:hget (id, "secrets")
      if not secrets then
        error "Incorrect username/password"
      end
      secrets = Platform.json.decode (secrets)
      if Platform.password.verify (t.password, secrets.password) then
        session.username = username
      else
        error "Incorrect username/password"
      end
    end)
    return true
  end) ()
end

function Backend.create_user (session, t, interactive)
  return Backend.coroutine.wrap (function ()
    local parameters = {
      username = Parameters.username,
      password = Parameters.password,
      name     = Parameters.name,
      email    = Parameters.email,
      language = Parameters.language,
    }
    if interactive then
      t = Backend.coroutine.yield (parameters)
    end
    check (parameters, t)
    local id = "/${username}" % {
      username = t.username,
    }
    local validation_key = Platform.unique.uuid ()
    Backend.pool.transaction ({ id }, function (redis)
      if redis:exists (id) then
        error ("${username} exists already" % {
          username = t.username,
        })
      end
      redis:hset (id, "metadata", Platform.json.encode {
        username = t.username,
      })
      redis:hset (id, "secrets", Platform.json.encode {
        password   = t.password,
        validation = validation_key,
      })
      redis:hset (id, "contents", Platform.json.encode {})
    end)
    Email.send {
      from    = "CosyVerif Platform <test.cosyverif@gmail.com>",
      to      = "${name} <${email}>" % {
        name  = t.name,
        email = t.email,
      },
      subject = "[CosyVerif] New account",
      body    = Configuration.message.registration % {
        username = t.username,
        key      = validation_key,
      },
    }
    return true
  end) ()
end

function Backend:delete_user (t)
end

function Backend:create_project (t)
end

function Backend:delete_project (t)
end

function Backend:create_resource (t)
end

function Backend:delete_resource (t)
end

function Backend:list (t)
end

function Backend:update (t)
end

function Backend:edit (t)
end

function Backend:patch (t)
end

return Backend