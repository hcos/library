-- Methods
-- =======

-- The `Utility` table contains all utility functions used within methods.
local Utility  = {}
-- The `Methods` table contains all available methods.
local Methods  = {}
-- The `Request` table defines and checks requests.
local Request  = {}
-- The `Response` table defines and checks responses.
local Response = {}
-- The `Parameters` table contains functions to check request parameters.
local Parameters = {}

-- TODO
-- ----
--
-- * use data to represent data stored in redis
-- * create a hook to remove data after a timeout

-- Dependencies
-- ------------
--
-- This module depends on the following modules:
                      require "compat53"
                      require "cosy.string"
local Platform      = require "cosy.platform"
local Configuration = require "cosy.configuration" .whole
local Internal      = require "cosy.configuration" .internal
local Data          = require "cosy.data"

-- Methods
-- -------
--
-- Methods use the standard [JSON Web Tokens](http://jwt.io/) to authenticate users.
-- Each method takes two parameters: the decoded token contents,
-- and the request parameters.

--    >  Platform      = require "cosy.platform"
--    >> Methods       = require "cosy.methods".Localized
--    >> Configuration = require "cosy.configuration" .whole
--    (...)

--    >  Configuration.token.secret = "secret"
--    >> Configuration.server.name  = "CosyTest"
--    >> Configuration.server.email = "test@cosy.org"
--    (...)

--    >  local response = Methods.create_user (nil, {
--    >>   username       = "username",
--    >>   password       = "password",
--    >>   email          = "username@domain.org",
--    >>   name           = "User Name",
--    >>   license_digest = "d41d8cd98f00b204e9800998ecf8427e",
--    >> })
--    >> print (Platform.table.representation (response))
--    >> print (Platform.table.representation (Platform.email.last_sent))
--    ...
--    {locale="en",success=true}
--    {body={"email:new_account:body",username="username",validation="..."},from={"email:new_account:from",email="test@cosy.org",name="CosyTest"},locale="en",subject={"email:new_account:subject",servername="CosyTest",username="username"},to={"email:new_account:to",email="username@domain.org",name="User Name"}}
--    (...)

function Methods.create_user (_, request)
  request:required {
    username        = Parameters.username,
    password        = Parameters.password,
    email           = Parameters.email,
    name            = Parameters.name,
    license_digest  = Parameters.license_digest,
  }
  request:optional {
    locale          = Parameters.locale,
  }
  local validation_token = Platform.token.encode {
    username = request.username,
  }
  Utility.redis.transaction ({
    email = Configuration.redis.key.email._ % { email    = request.email    },
    token = Configuration.redis.key.token._ % { token    = validation_token },
    data  = Configuration.redis.key.user._  % { username = request.username },
  }, function (p)
    if p.email._ then
      error {
        status   = "create-user:email-exists",
        email    = request.email,
      }
    end
    if p.token._ then
      error {
        status   = "token:exists",
        email    = request.email,
      }
    end
    if p.data._ then
      error {
        status   = "create-user:username-exists",
        username = request.username,
      }
    end
    local expire_at = Platform.time () + Configuration.account.expire._
    p.data = {
      _           = true,
      type        = "user",
      status      = "created",
      username    = request.username,
      email       = request.email,
      password    = Platform.password.hash (request.password),
      name        = request.name,
      locale      = request.locale or Configuration.locale.default._,
      expire_at   = expire_at,
      validation  = validation_token,
      access      = {
        public = true,
      },
      contents    = {},
    }
    p.email = {
      _         = true,
      expire_at = expire_at,
    }
    p.token = {
      _         = true,
      expire_at = expire_at,
    }
  end)
  Utility.redis.transaction ({
    data = Configuration.redis.key.user._ % { username = request.username },
  }, function (p)
    Platform.email.send {
      locale  = p.data.locale._,
      from    = {
        "email:new_account:from",
        name  = Configuration.server.name._,
        email = Configuration.server.email._,
      },
      to      = {
        "email:new_account:to",
        name  = p.data.name._,
        email = p.data.email._,
      },
      subject = {
        "email:new_account:subject",
        servername = Configuration.server.name._,
        username   = p.data.username._,
      },
      body    = {
        "email:new_account:body",
        username   = p.data.username._,
        validation = p.data.validation._,
      },
    }
  end)
end

-- Storage keys
-- ------------

Internal.redis.key = {
  user  = "user:%{username}",
  email = "email:%{email}",
  token = "token:%{token}",
}

-- Request
-- -------

Request.__index = Request
Request.__metatable = "Request"

function Request.new (t)
  return setmetatable (t, Request)
end

function Request.required (request, t)
  for key, parameter in pairs (t) do
    local value = t [key]
    if value == nil then
      error {
        status     = "check:error",
        reason     = {
          "check:missing",
          key = key,
        },
        parameters = t,
      }
    end
    for _, f in ipairs (parameter) do
      local ok, reason = f (request)
      if not ok then
        error {
          status     = "check:error",
          reason     = reason,
          parameters = t,
        }
      end
    end
  end
end

function Request.optional (request, t)
  for key, parameter in pairs (t) do
    local value = request [key]
    if value ~= nil then
      for _, f in ipairs (parameter) do
        local ok, reason = f (request)
        if not ok then
          error {
            status     = "check:error",
            reason     = reason,
            parameters = t,
          }
        end
      end
    end
  end
end

-- Response
-- --------

Response.__index     = Response
Response.__metatable = "Response"

function Response.new (t)
  return setmetatable (t, Response)
end

function Response.__tostring (response)
  return Platform.i18n.translate (response.status, response)
end

-- Parameters
-- ----------

function Parameters.new_string (key)
  Internal.data [key] .min_size._ = 0
  Internal.data [key] .max_size._ = math.huge
  Parameters [key] = {}
  Parameters [key] [1] = function (request)
    return  type (request [key]) == "string"
        or  nil, {
              "check:is-string",
              key = key,
            }
  end
  Parameters [key] [2] = function (request)
    return  #(request [key]) >= Configuration.data [key] .min_size._
        or  nil, {
              "check:min-size",
              key    = key,
              count  = Configuration.data [key] .min_size._,
            }
  end
  Parameters [key] [3] = function (request)
    return  #(request [key]) <= Configuration.data [key] .max_size._
        or  nil, {
              "check:max-size",
              key    = key,
              count  = Configuration.data [key].max_size._,
            }
  end
  return Parameters [key]
end

Parameters.new_string "username"
Parameters.username [#(Parameters.username) + 1] = function (request)
  request.username = request.username:trim ()
  return  request.username:find "^%w+$"
      or  nil, {
            "check:username:alphanumeric",
            username = request.username,
          }
end

Parameters.new_string "password"

Parameters.new_string "email"
Parameters.email [#(Parameters.email) + 1] = function (request)
  request.email = request.email:trim ()
  local pattern = "^.*@[%w%.%%%+%-]+%.%w%w%w?%w?$"
  return  request.email:find (pattern)
      or  nil, {
            "check:email:pattern",
            email = request.email,
          }
end

Parameters.new_string "name"

Parameters.new_string "locale"
Internal.data.locale.min_size = 2
Internal.data.locale.max_size = 5
Parameters.locale [#(Parameters.locale) + 1] = function (request)
  request.locale = request.locale:trim ()
  return  request.locale:find "^%a%a$"
      or  request.locale:find "^%a%a_%a%a$"
      or  nil, {
            "check:locale:pattern",
            locale = request.locale,
          }
end

Parameters.new_string "validation"

Parameters.new_string "license_digest"
Internal.data.license_digest.min_size = 32
Internal.data.license_digest.max_size = 32
Parameters.license_digest [#(Parameters.license_digest) + 1] = function (request)
  request.license_digest = request.license_digest:trim ()
  local pattern = "^%x+$"
  return  request.license_digest:find (pattern)
      or  nil, {
            "check:license_digest:pattern",
            license_digest = request.license_digest,
          }
end

-- Utility
-- -------

Utility.redis = {
  pool = {
    created = {},
    free    = {},
  }
}

Internal.redis.retry._ = 5

function Utility.redis.transaction (keys, f)
  local client
  while true do
    client = pairs (Utility.redis.pool.free) (Utility.redis.pool.free)
    if client then
      Utility.redis.pool.free [client] = nil
      break
    end
    if #Utility.redis.pool.created < Configuration.redis.pool_size._ then
      if Platform.redis.is_fake then
        client = Platform.redis.connect ()
      else
        local socket    = require "socket"
        local coroutine = require "coroutine.make" ()
        local host      = Configuration.redis.host._
        local port      = Configuration.redis.port._
        local database  = Configuration.redis.database._
        local skt       = Platform.scheduler:wrap (socket.tcp ()):connect (host, port)
        client = Platform.redis.connect {
          socket    = skt,
          coroutine = coroutine,
        }
        client:select (database)
      end
      Utility.redis.pool.created [#Utility.redis.pool.created + 1] = client
      break
    else
      Platform.scheduler:pass ()
    end
  end
  local ok, result = pcall (client.transaction, client, {
    watch = keys,
    cas   = true,
    retry = Configuration.redis.retry_,
  }, function (redis)
    local written = {}
    local data = Data.new ()
    data.default = {}
    local t    = data.default
    local raw  = Data.raw (data).default
    for k, v in pairs (keys) do
      if redis:exists (v) then
        raw [k] = Platform.json.decode (redis:get (v))
      end
    end
    Data.options (data) .filter = function (d)
      local expire_at = d.expire_at._
      return expire_at
         and expire_at < Platform.time ()
          or true
    end
    Data.options (data) .on_write = function (d)
      written [Data.path (d) [2]] = true
    end
    f (t, client)
    Data.options (data) .filter   = nil
    Data.options (data) .on_write = nil
    if pairs (written) (written) then
      redis:multi ()
      for k in pairs (written) do
        local redis_key = keys [k]
        local value     = raw  [k]
        if value == nil then
          redis:del (redis_key)
        else
          redis:set (redis_key, Platform.json.encode (value))
          if value.expire_at then
            redis:expireat (redis_key, value.expire_at)
          else
            redis:persist (redis_key)
          end
        end
      end
    end
  end)
  Utility.redis.pool.free [client] = true
  if ok then
    return result
  else
    error (result)
  end
end

--[==[
function Methods.validate_user (session, t)
  if session.username ~= nil then
    error {
      status = "validate-user:connected-already",
    }
  end
  local parameters = {
    username       = Parameters.username,
    validation_key = Parameters.validation_key,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  Backend.pool.transaction ({
    data   = Configuration.redis.key.user._ % { username = t.username },
  }, function (p)
    if not p.data then
      error {
        status   = "validate-user:non-existing",
        username = t.username,
      }
    end
    if p.data.type ~= "user" then
      error {
        status = "validate-user:non-user",
      }
    end
    if p.data.validation_key == nil then
      error {
        status = "validate-user:validated-already",
      }
    end
    if p.data.validation_key ~= t.validation_key then
      error {
        status = "validate-user:erroneous",
      }
    end
    p.data.validation_key = nil
  end)
end

function Methods.license (session, t)
  local parameters = {
    locale = Parameters.locale,
  }
  Backend.localize (session, t)
  Backend.check    (session, t, parameters)
  local license = Platform.i18n.translate ("license", {
    locale = session.locale
  }):trim ()
  local license_md5 = Platform.md5.digest (license)
  return {
    license = license,
    digest  = license_md5,
  }
end

function Methods.authenticate (session, t)
  local parameters = {
    username = Parameters.username,
    password = Parameters.password,
    ["license?"] = Parameters.license,
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
    if data.validation_key then
      error {
        status = "authenticate:non-validated",
      }
    end
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
      if t.license and t.license == license_md5 then
        data.accepted_license = license_md5
      elseif t.license and t.license ~= license_md5 then
        error {
          status   = "license:oudated",
          username = t.username,
          digest   = license_md5,
        }
      else
        error {
          status   = "license:reject",
          username = t.username,
          digest   = license_md5,
        }
      end
    end
  end)
  session.username = t.username
end

function Methods.reset_user (session, t)
end

function Methods:delete_user (t)
end

function Methods.metadata (session, t)
end

function Methods:create_project (t)
end

function Methods:delete_project (t)
end

function Methods:create_resource (t)
end

function Methods:delete_resource (t)
end

function Methods:list (t)
end

function Methods:update (t)
end

function Methods:edit (t)
end

function Methods:patch (t)
end


-- 




function Backend.localize (session, t)
  local locale
  if type (t) == "table" and t.locale then
    locale = t.locale
  elseif session.locale then
    locale = session.locale
  else
    locale = Configuration.locale.default._
  end
  session.locale = locale
end

function Backend.check (session, t, parameters)
  for key, parameter in pairs (parameters) do
    local optional = key:find "?$"
    if optional then
      key = key:sub (1, #key-1)
    end
    local value = t [key]
    if value == nil and not optional then
      error {
        status     = "check:error",
        reason     = Platform.i18n.translate ("check:missing", {
           locale = session.locale,
           key    = key,
         }),
        parameters = parameters,
      }
    elseif value ~= nil then
      for _, f in ipairs (parameter) do
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
end


--]==]

local Exported = {}

do
  Exported.Localized = {}
  local function wrap (method)
    return function (token, request)
      local ok, response
      if token then
        ok, token = pcall (Platform.token.decode, token)
      else
        ok, token = true, {}
      end
      if not ok then
        return Response.new {
          status  = "token:error",
          locale  = Configuration.locale.default._,
          reason  = token,
        }
      end
      request = Request.new (request)
      method (token, request)
--      ok, response = pcall (method, token, request)
      if type (response) ~= "table" then
        response = {
          reason  = response,
        }
      end
      response = Response.new (response)
      response.success = ok
      response.locale  = token.locale or Configuration.locale.default._
      return response
    end
  end
  for k, v in pairs (Methods) do
    Exported.Localized [k] = wrap (v)
  end
end

return Exported