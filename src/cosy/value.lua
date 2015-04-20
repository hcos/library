local loader  = require "cosy.loader"
local hotswap = loader.hotswap

local Value   = {}

function Value.encode (t, options)
  local serpent = hotswap "serpent"
  return serpent.dump (t, options or {
    sortkeys = false,
    compact  = true,
    fatal    = true,
    comment  = false,
  })
end

function Value.expression (t, options)
  local serpent = hotswap "serpent"
  return serpent.line (t, options or {
    sortkeys = true,
    compact  = true,
    fatal    = true,
    comment  = false,
    nocode   = true,
  })
end

function Value.decode (s)
  local serpent = hotswap "serpent"
  local ok, result = serpent.load (s, {
    safe = false,
  })
  if not ok then
    error (result)
  end
  return result
end

return Value