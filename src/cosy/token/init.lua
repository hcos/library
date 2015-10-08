if _G.js then
  error "Not available"
end

local Configuration = require "cosy.configuration"
local Digest        = require "cosy.digest"
local Random        = require "cosy.random"
local Time          = require "cosy.time"
local Jwt           = require "jwt"
local App           = require "cosy.configuration.layers".app

Configuration.load "cosy.token"

if Configuration.token.secret == nil then
  App.token = {
    secret = Digest (Random ())
  }
end

local Token = {}

function Token.encode (token)
  local options = {
    alg  = Configuration.token.algorithm,
    keys = { private = Configuration.token.secret },
  }
  local result, err = Jwt.encode (token, options)
  if not result then
    error (err)
  end
  return result
end

function Token.decode (s)
  local options = {
    alg  = Configuration.token.algorithm,
    keys = { private = Configuration.token.secret },
  }
  local result, err = Jwt.decode (s, options)
  if not result then
    error (err)
  end
  return result
end

function Token.administration ()
  local now    = Time ()
  local result = {
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.administration,
    iss      = Configuration.server.name,
    aud      = nil,
    sub      = "cosy:administration",
    jti      = Digest (tostring (now + Random ())),
    contents = {
      type       = "administration",
      passphrase = Configuration.server.passphrase,
    },
  }
  return Token.encode (result)
end

function Token.validation (data)
  local now    = Time ()
  local result = {
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.validation,
    iss      = Configuration.server.name,
    aud      = nil,
    sub      = "cosy:validation",
    jti      = Digest (tostring (now + Random ())),
    contents = {
      type       = "validation",
      identifier = data.identifier,
      email      = data.email,
    },
  }
  return Token.encode (result)
end

function Token.authentication (data)
  local now    = Time ()
  local result = {
    iat      = now,
    nbf      = now - 1,
    exp      = now + Configuration.expiration.authentication,
    iss      = Configuration.server.name,
    aud      = nil,
    sub      = "cosy:authentication",
    jti      = Digest (tostring (now + Random ())),
    contents = {
      type       = "authentication",
      identifier = data.identifier,
      locale     = data.locale,
    },
  }
  return Token.encode (result)
end

return Token
