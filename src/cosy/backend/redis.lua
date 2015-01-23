local Backend = {}

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"
local ignore        = require "cosy.util.ignore"

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

Backend.coroutine = require "coroutine.make" ()

-- Fix missing `table.unpack` in lua 5.1:
table.unpack = table.unpack or _G.unpack

function Backend.__index (_, key)
  local result = Backend [key]
  if type (result) == "function" then
    return function (...)
      local args = { ... }
      return Backend.coroutine.wrap (function ()
        return result (table.unpack (args))
      end) ()
    end
  else
    return result
  end
end

function Backend.localize (session, t)
  local locale
  if type (t) == "table" and t.locale then
    locale = t.locale
  elseif session.locale then
    locale = session.locale
  else
    locale = Configuration.locale.default
  end
  session.locale = locale
end

function Backend.check (session, t, parameters)
  local reasons = {}
  for key in pairs (t) do
    for i, f in ipairs (parameters [key]) do
      local ok, r = f (session, t)
      if not ok then
        reasons [#reasons + 1] = r
        break
      end
    end
  end
  if #reasons ~= 0 then
    error {
      status     = "check:error",
      message    = Platform.i18n.translate ("check:error", {
        locale = locale,
      }),
      reasons    = reasons,
      parameters = parameters,
    }
  end
end

-- All methods can return:
-- * `true, data`
-- * `false, data`
-- Data can be:
-- * `parameters`
-- * `reasons`
-- * ...

-- locale is specified:
-- * as a request parameter;
-- * in the session;
-- * in user's account;
-- * in the global configuration.

local Parameters = {}

function Parameters.new_string (key)
  Parameters [key] = {}
  Parameters [key] [1] = function (session, t)
    return type (t [key]) == "string"
        or nil, Platform.i18n.translate ("check:is-string", {
             locale = session.locale,
             key    = key,
           })
  end
  Parameters [key] [2] = function (session, t)
    return #(t [key]) >= Configuration.data [key] .min_size
        or nil, Platform.i18n.translate ("check:min-size", {
             locale = session.locale,
             key    = key,
             count  = Configuration.data [key] .min_size,
           })
  end
  Parameters [key] [3] = function (session, t)
    return #(t.username) <= Configuration.data [key] .max_size
        or nil, Platform.i18n.translate ("check:max-size", {
             locale = session.locale,
             key    = key,
             count  = Configuration.data [key].max_size,
           })
  end
  return Parameters [key]
end

Parameters.new_string "username"
Parameters.username [#(Parameters.username) + 1] = function (session, t)
  return t.username:find "^%w+$"
      or nil, Platform.i18n.translate ("check:username:alphanumeric", {
           locale = session.locale,
         })
end

Parameters.new_string "password"

Parameters.new_string "email"
Parameters.email [#(Parameters.email) + 1] = function (session, t)
  t.email = t.email:trim ()
  local pattern = "^[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?"
  return t.email:find (pattern)
      or nil, Platform.i18n "check:email:pattern"
end

Parameters.new_string "name"

Parameters.new_string "locale"
Parameters.locale [#(Parameters.locale) + 1] = function (session, t)
  t.locale = t.locale:trim ()
  local pattern = "^[A-Za-z][A-Za-z](_[A-Za-z][A-Za-z])?"
  return t.locale:find (pattern)
      or nil, Platform.i18n "check:locale:pattern"
end

Parameters.resource = {}
Parameters.resource [1] = function (session, t)
  return true -- TODO
end

-- TODO: access lists:
-- * groups defined by the owner(s)
-- * access is "public"/"private" with optional "owner" "share", "read" or "hide" for group/user

function Backend.authenticate (session, t)
  local parameters = {
    username = Parameters.username,
    password = Parameters.password,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  local id = "/%{username}" % {
    username = t.username,
  }
  session.username = nil
  Backend.pool.transaction ({ id }, function (redis)
    local metadata = redis:hget (id, "metadata")
    if not metadata then
      error {
        status  = "authenticate:non-existing",
        message = "authenticate:non-existing",
      }
    end
    metadata = Platform.json.decode (metadata)
    if metadata.type ~= "user" then
      error {
        status  = "authenticate:non-user",
        message = "authenticate:non-user",
      }
    end
    local secrets  = redis:hget (id, "secrets")
    secrets = Platform.json.decode (secrets)
    -- end of reads
    redis:multi ()
    if Platform.password.verify (t.password, secrets.password) then
      session.username = t.username
    else
      error {
        status  = "authenticate:erroneous",
        message = "authenticate:erroneous",
      }
    end
    if Platform.password.is_too_cheap (secrets.password) then
      Platform.logger.debug {
        "authenticate:cheap-password",
        username = t.username,
      }
      secrets.password = Platform.password.hash (t.password)
      redis:hset (id, "secrets", Platform.json.encode (secrets))
    end
    if metadata.locale then
      session.locale = metadata.locale
    end
  end)
  return true
end

function Backend.create_user (session, t)
  local parameters = {
    username = Parameters.username,
    password = Parameters.password,
    email    = Parameters.email,
    name     = Parameters.name,
    locale   = Parameters.locale,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
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
end

function Backend:delete_user (t)
end

function Backend.metadata (session, t)
  local parameters = {
    Parameters.resource,
  }
  localize (session, t)
  check    (session, t, parameters)
  return {
    url = "http://${host}:${port}/" % {
      host = Configuration.server.host,
      port = Configuration.server.port,
    }
    -- TODO: fill with public server information
  }
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