local loader  = require "cosy.loader"
local hotswap = loader.hotswap

if _G.js then
  error "Not available"
end

local configuration = loader.configuration
if configuration.token.secret._ == nil then
  error {
    _ = "token:no-secret",
  }
end

local Token = {}

function Token.encode (token)
  local jwt           = hotswap "luajwt"
  local configuration = loader.configuration
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
  local configuration = loader.configuration
  local key           = configuration.token.secret._
  local algorithm     = configuration.token.algorithm._
  local result, err   = jwt.decode (s, key, algorithm)
  if not result then
    error (err)
  end
  return result
end

return Token