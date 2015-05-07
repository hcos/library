local loader  = require "cosy.loader"

return function (x)
  if type (x) ~= "table" then
    return x
  end
  local i18n    = loader.hotswap "i18n"
  local logger  = loader.logger
  local locale  = x.locale
  if not locale then
    local configuration = loader.configuration
    locale = configuration.locale._
  end
  local package     = "cosy.i18n." .. locale
  local loaded      = loader.hotswap.loaded [package]
  local translation = loader.hotswap (package, true)
  if translation and not loaded then
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
