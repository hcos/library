local loader  = require "cosy.loader"

local Value   = {}

function Value.encode (t, options)
  local serpent = loader "serpent"
  return serpent.dump (t, options or {
    sortkeys = false,
    compact  = true,
    fatal    = true,
    comment  = false,
  })
end

function Value.expression (t, options)
  local serpent = loader "serpent"
  return serpent.line (t, options or {
    sortkeys = true,
    compact  = true,
    fatal    = true,
    comment  = false,
    nocode   = true,
  })
end

function Value.decode (s)
  local serpent = loader "serpent"
  local ok, result = serpent.load (s, {
    safe = false,
  })
  if not ok then
    error (result)
  end
  return result
end

return Value