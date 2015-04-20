local hotswap = require "hotswap"

if _G.js then
  local js = _G.js
  local sjcl = js.global.require "sjcl.js"
  js.global.require "sha256.js"
  return function (s)
    local out = sjcl.hash.sha1.hash (s)
    return sjcl.codec.hex.fromBits (out)
  end
else
  return function (s)
    local Crypto = hotswap "crypto"
    return Crypto.hex (Crypto.digest ("SHA256", s))
  end
end
