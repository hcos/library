local loader  = require "cosy.loader"

if _G.js then
  local js = _G.js
  local sjcl = js.global.require "sjcl.js"
  return function (s)
    local out = sjcl.hash.sha512:hash (s)
    return sjcl.codec.hex.fromBits (out)
  end
else
  return function (s)
    local Crypto = loader.hotswap "crypto"
    return Crypto.digest ("SHA512", s)
  end
end
