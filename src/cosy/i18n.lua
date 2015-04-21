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

  local function translate (x)
    if type (x) ~= "table" then
      return x
    end
    for _, v in pairs (x) do
      if type (v) == "table" and not getmetatable (v) then
        local vl  = v.locale
        v.locale  = x.locale
        v.message = translate (v)
        v.locale  = vl
      end
    end
    if x._ then
      x.message = i18n.translate (x._, x)
    end
    return x
  end
  return tostring (translate (x).message)
end
