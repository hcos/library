local Loader = require "cosy.loader"

if _G.js then
  local script = Loader.loadhttp "/js/sjcl.js"
  _G.window.jQuery:globalEval (script)
  return function (s)
    local out = _G.window.sjcl.hash.sha256:hash (s)
    return _G.window.sjcl.codec.hex:fromBits (out)
  end
else
  return function (s)
    local Crypto = require "crypto"
    return Crypto.digest ("SHA256", s)
  end
end
