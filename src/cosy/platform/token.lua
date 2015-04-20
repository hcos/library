local hotswap = require "hotswap"

if _G.js then
  error "Not available"
end

local configuration = hotswap "cosy.platform.configuration"
if configuration.token.secret._ == nil then
  error {
    _ = "platform:no-token-secret",
  }
end

local Token = {}

function Token.encode (token)
  local jwt           = hotswap "luajwt"
  local configuration = hotswap "cosy.platform.configuration"
  local secret        = configuration.token.secret._
  local algorithm     = configuration.token.algorithm._
  local result, err   = jwt.encode (token, secret, algorithm)
  if not result then
    error (err)
  end
  return result
end

function Token.decode (s)
  local jwt           = hotswap "luajwt"
  local configuration = hotswap "cosy.platform.configuration"
  local key           = configuration.token.secret._
  local algorithm     = configuration.token.algorithm._
  local result, err   = jwt.decode (s, key, algorithm)
  if not result then
    error (err)
  end
  return result
end

return Token