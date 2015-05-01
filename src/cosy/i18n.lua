local loader  = require "cosy.loader"
local hotswap = loader.hotswap

return function (x)
  if type (x) ~= "table" then
    return x
  end
  local i18n    = hotswap "i18n"
  local logger  = loader.logger
  local locale  = x.locale
  if not locale then
    local configuration = loader.configuration
    locale = configuration.locale._
  end
  local translation, new = hotswap ("cosy.i18n." .. locale, true)
  if translation and new then
    i18n.load {
      [locale] = translation,
    }
    logger.info {
      _      = "locale:available",
      loaded = locale,
      locale = locale,
    }
  elseif not translation then
    logger.info {
      _      = "locale:missing",
      loaded = locale,
      locale = locale,
    }
  end

  local function translate (t)
    if type (t) ~= "table" then
      return t
    end
    for _, v in pairs (t) do
      if type (v) == "table" and not getmetatable (v) then
        local vl  = v.locale
        v.locale  = t.locale
        translate (v)
        v.locale  = vl
      end
    end
    if t._ then
      t.message = i18n.translate (t._, t)
    end
    return x
  end
  return tostring (translate (x).message)
end
