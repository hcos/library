local Backend = {}

local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration"

Configuration.special_keys = {
  email_user = "//email->user",
}

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
  }, function (redis)
    local t = {}
    for k, v in pairs (keys) do
      if redis:exists (v) then
        t [k] = Platform.json.decode (redis:get (v))
      end
    end
    f (t)
    redis:multi ()
    for k, v in pairs (keys) do
      if t [k] == nil then
        redis:del (v)
      else
        redis:set (v, Platform.json.encode (t [k]))
      end
    end
  end)
  pool [#pool + 1] = client
  if ok then
    return result
  else
    error (result)
  end
end

Backend.coroutine = require "coroutine.make" ()

-- Fix missing `table.unpack` in lua 5.1:
table.unpack = table.unpack or _G.unpack

local Message_mt = {}

function Message_mt:__tostring ()
  return self.message
end

function Backend.__index (session, key)
  local value = Backend [key]
  if type (value) == "function" then
    local first = true
    local co    = Backend.coroutine.create (value)
    return function (t)
      local ok, r, e
      if first then
        ok, r, e = Backend.coroutine.resume (co, session, t)
        first = false
      else
        ok, r, e = Backend.coroutine.resume (co, t)
      end
      if ok and r ~= nil then
        return r
      elseif ok and r == nil then
        e.locale  = session.locale or Configuration.locale.default
        e.message = Platform.i18n.translate (e.request, e)
        return nil, setmetatable (e, Message_mt)
      elseif type (r) == "table" then
        r.locale  = session.locale or Configuration.locale.default
        r.message = Platform.i18n.translate (r.status, r)
        error (setmetatable (r, Message_mt))
      else
        error (r)
      end
    end
  else
    return value
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
  for key in pairs (t) do
    for _, f in ipairs (parameters [key]) do
      local ok, r = f (session, t)
      if not ok then
        error {
          status     = "check:error",
          reason     = r,
          parameters = parameters,
        }
      end
    end
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
    return #(t [key]) <= Configuration.data [key] .max_size
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
Configuration.data.email.min_size = 6
Parameters.email [#(Parameters.email) + 1] = function (session, t)
  local _ = session
  t.email = t.email:trim ()
  local pattern = "^[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?"
  return t.email:find (pattern)
      or nil, Platform.i18n "check:email:pattern"
end

Parameters.new_string "name"

Parameters.new_string "locale"
Configuration.data.locale.min_size = 2
Configuration.data.locale.max_size = 5
Parameters.locale [#(Parameters.locale) + 1] = function (session, t)
  local _ = session
  t.locale = t.locale:trim ()
  local pattern = "^[A-Za-z][A-Za-z](_[A-Za-z][A-Za-z])?"
  return t.locale:find (pattern)
      or nil, Platform.i18n "check:locale:pattern"
end

Parameters.resource = {}
Parameters.resource [1] = function (session, t)
  local _ = session
        _ = t
  return true -- TODO
end

-- TODO: access lists:
-- * groups defined by the owner(s)
-- * access is "public"/"private" with optional "owner" "share", "read" or "hide" for group/user

-- User:
-- * type: "user"
-- * password: ...
-- * locale: ...
-- * license-md5: ...

function Backend.authenticate (session, t)
  local parameters = {
    username = Parameters.username,
    password = Parameters.password,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  session.username = nil
  Backend.pool.transaction ({
    data = "/%{username}" % {
      username = t.username,
    }
  }, function (p)
    local data = p.data
    if not data then
      error {
        status = "authenticate:non-existing",
      }
    end
    if data.type ~= "user" then
      error {
        status = "authenticate:non-user",
      }
    end
    session.locale = data.locale or session.locale
    if not Platform.password.verify (t.password, data.password) then
      error {
        status = "authenticate:erroneous",
      }
    end
    if Platform.password.is_too_cheap (data.password) then
      Platform.logger.debug {
        "authenticate:cheap-password",
        username = t.username,
      }
      data.password = Platform.password.hash (t.password)
    end
    local license = Platform.i18n.translate ("license", {
      locale = session.locale
    }):trim ()
    local license_md5 = Platform.md5.digest (license)
    if license_md5 ~= data.accepted_license then
      local answer = Backend.coroutine.yield (nil, {
        request = "license:accept?",
        license = license,
        digest  = license_md5,
      })
      if answer.response:trim () ~= license_md5 then
        error {
          status   = "license:reject",
          username = t.username,
          digest   = license_md5,
        }
      end
      data.accepted_license = license_md5
      Platform.logger.debug {
        "license:accept",
        username = t.username,
        digest   = license_md5,
      }
    end
  end)
  session.username = t.username
  return true
end

function Backend.create_user (session, t)
  if session.username ~= nil then
    error {
      status = "create-user:connected-already",
    }
  end
  local parameters = {
    username = Parameters.username,
    password = Parameters.password,
    email    = Parameters.email,
    name     = Parameters.name,
    locale   = Parameters.locale,
  }
  local data
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  Backend.pool.transaction ({
    emails = Configuration.special_keys.email_user,
    data   = "/${username}" % {
      username = t.username,
    },
  }, function (p)
    if p.emails [t.email] then
      error {
        status   = "create-user:email-already",
        email    = t.email,
        username = p.emails [t.email],
      }
    end
    if p.data then
      error {
        status   = "create-user:username-already",
        username = t.username,
      }
    end
    local license     = Platform.i18n.translate ("license", session.locale):trim ()
    local license_md5 = Platform.md5.digest (license)
    local answer = Backend.coroutine.yield {
      "accept-license",
      license = license,
      md5     = license_md5,
    }
    if answer:trim () ~= license_md5 then
      error {
        status = "create-user:reject-license",
      }
    end
    p.data = {
      username          = t.username,
      password          = Platform.password.hash (t.password),
      name              = t.name,
      locale            = t.locale,
      accepted_license  = license_md5,
      validation_key    = Platform.unique.uuid (),
      access            = {
        public = true,
      },
      contents          = {},
    }
    p.emails [t.email]  = t.username
    data = p.data
  end)
  Platform.Email.send {
    from    = Platform.i18n.translate ("email:new_account:from", {
      locale  = session.locale,
      address = Configuration.smtp.username,
    }),
    to      = "${name} <${email}>" % {
      name  = data.name,
      email = data.email,
    },
    subject = Platform.i18n.translate ("email:new_account:subject", {
      locale   = session.locale,
      username = data.username,
    }),
    body    = Platform.i18n.translate ("email:new_account:body", {
      locale   = session.locale,
      username = data.username,
      key      = data.validation_key,
    }),
  }
  session.username = nil
  return true
end

function Backend:validate_user (t)
end

function Backend:reset_user (t)
end

function Backend:delete_user (t)
end

function Backend.metadata (session, t)
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