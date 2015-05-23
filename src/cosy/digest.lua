local Loader = require "cosy.loader"

if _G.js then
  local script = Loader.loadhttp "/js/sjcl.js"
  _G.js.global:eval (script)
  return function (s)
    local out = _G.js.global.sjcl.hash.sha512:hash (s)
    return _G.js.global.codec.hex:fromBits (out)
  end
else
  return function (s)
    local Crypto = require "crypto"
    return Crypto.digest ("SHA512", s)
  end
end
