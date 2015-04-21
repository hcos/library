local loader  = require "cosy.loader"

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
    local Crypto = loader.hotswap "crypto"
    return Crypto.digest ("SHA256", s)
  end
end
