local Loader = require "cosy.loader"

if _G.js then
  local script = Loader.loadhttp "/js/sjcl.js"
  --_G.js.global:eval (script)
  window.jQuery:globalEval (script)
  return function (s)
    local out = _G.js.global.sjcl.hash.sha256:hash (s)
    return _G.js.global.sjcl.codec.hex:fromBits (out)
  end
else
  return function (s)
    local Crypto = require "crypto"
    return Crypto.digest ("SHA256", s)
  end
end
