local Serpent = require "serpent"

local Value   = {}

function Value.encode (t, options)
  return Serpent.dump (t, options or {
    sortkeys = false,
    compact  = true,
    fatal    = true,
    comment  = false,
  })
end

function Value.expression (t, options)
  return Serpent.line (t, options or {
    sortkeys = true,
    compact  = true,
    fatal    = true,
    comment  = false,
    nocode   = true,
  })
end

function Value.decode (s)
  local ok, result = Serpent.load (s, {
    safe = false,
  })
  if not ok then
    error (result)
  end
  return result
end

return Value