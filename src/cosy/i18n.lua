local i18n = require "i18n"

return function (x)
  if type (x) ~= "table" then
    return x
  end
  local locale  = x.locale
  if not locale then
    locale = "en"
  end
  local Loader      = require "cosy.loader"
  local Logger      = require "cosy.logger"
  local package     = "cosy.i18n." .. locale
  local loaded      = Loader.hotswap.loaded [package]
  local translation = Loader.hotswap.try_require (package)
  if translation and not loaded then
    i18n.load {
      [locale] = translation,
    }
    Logger.info {
      _      = "locale:available",
      loaded = locale,
      locale = locale,
    }
  elseif not translation then
    Logger.info {
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
