local loader  = require "cosy.loader"
local hotswap = loader.hotswap

if _G.js then
  error "Not available"
end

if loader.configuration.token.secret._ == nil then
  error {
    _ = "token:no-secret",
  }
end

local Token = {}

function Token.encode (token)
  local jwt           = hotswap "luajwt"
  local secret        = loader.configuration.token.secret._
  local algorithm     = loader.configuration.token.algorithm._
  local result, err   = jwt.encode (token, secret, algorithm)
  if not result then
    error (err)
  end
  return result
end

function Token.decode (s)
  local jwt           = hotswap "luajwt"
  local key           = loader.configuration.token.secret._
  local algorithm     = loader.configuration.token.algorithm._
  local result, err   = jwt.decode (s, key, algorithm)
  if not result then
    error (err)
  end
  return result
end

function Token.administration ()
  local now    = loader.time ()
  local result = {
    contents = {
      type       = "administration",
      passphrase = loader.server.passphrase,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + loader.configuration.expiration.administration._,
    iss      = loader.configuration.server.name._,
    aud      = nil,
    sub      = "cosy:administration",
    jti      = loader.digest (tostring (now + loader.random ())),
  }
  return loader.token.encode (result)
end

function Token.validation (data)
  local now    = loader.time ()
  local result = {
    contents = {
      type     = "validation",
      username = data.username,
      email    = data.email,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + loader.configuration.expiration.validation._,
    iss      = loader.configuration.server.name._,
    aud      = nil,
    sub      = "cosy:validation",
    jti      = loader.digest (tostring (now + loader.random ())),
  }
  return loader.token.encode (result)
end

function Token.authentication (data)
  local now    = loader.time ()
  local result = {
    contents = {
      type     = "authentication",
      username = data.username,
      locale   = data.locale,
    },
    iat      = now,
    nbf      = now - 1,
    exp      = now + loader.configuration.expiration.authentication._,
    iss      = loader.configuration.server.name._,
    aud      = nil,
    sub      = "cosy:authentication",
    jti      = loader.digest (tostring (now + loader.random ())),
  }
  return loader.token.encode (result)
end

return Token