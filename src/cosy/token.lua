if _G.js then
  error "Not available"
end

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local I18n          = require "cosy.i18n"
local Random        = require "cosy.random"
local Time          = require "cosy.time"
local Jwt           = require "luajwt"

local i18n   = I18n.load (require "cosy.token-i18n")
i18n._locale = Configuration.locale._

if Configuration.token.secret._ == nil then
  error {
    _ = i18n ["token:no-secret"],
  }
end

local Token = {}

function Token.encode (token)
  local secret        = Configuration.token.secret._
  local algorithm     = Configuration.token.algorithm._
  local result, err   = Jwt.encode (token, secret, algorithm)
  if not result then
    error (err)
  end
  return result
end

function Token.decode (s)
  local key           = Configuration.token.secret._
  local algorithm     = Configuration.token.algorithm._
  local result, err   = Jwt.decode (s, key, algorithm)
  if not result then
    error (err)
  end
  return result
end

function Token.administration (server)
  local now    = Time ()
  local result = {
    contents = {
      type       = "administration",
      passphrase = server.passphrase,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.administration._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:administration",
    jti      = Digest (tostring (now + Random ())),
  }
  return Token.encode (result)
end

function Token.validation (data)
  local now    = Time ()
  local result = {
    contents = {
      type     = "validation",
      username = data.username,
      email    = data.email,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.validation._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:validation",
    jti      = Digest (tostring (now + Random ())),
  }
  return Token.encode (result)
end

function Token.authentication (data)
  local now    = Time ()
  local result = {
    contents = {
      type     = "authentication",
      username = data.username,
      locale   = data.locale,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.authentication._,
    iss      = Configuration.server.name._,
    aud      = nil,
    sub      = "cosy:authentication",
    jti      = Digest (tostring (now + Random ())),
  }
  return Token.encode (result)
end

return Token