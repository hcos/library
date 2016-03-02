return function (loader)

  local I18n      = loader.load "cosy.i18n"
  local Layer     = loader.require "layeredata"

  local MT        = {}
  local Webclient = setmetatable ({
    shown = {},
  }, MT)

  local function replace (t)
    if type (t) ~= "table" then
      return t
    elseif t._ then
      return t.message
    else
      for k, v in pairs (t) do
        t [k] = replace (v)
      end
      return t
    end
  end

  function MT.__call (_, f, ...)
    local args = { ... }
    loader.scheduler.addthread (function ()
      xpcall (function ()
        return f (table.unpack (args))
      end, function (err)
        print ("error:", err)
        print (debug.traceback ())
      end)
    end)
  end

  function Webclient.jQuery (key)
    return Webclient.window:jQuery (key)
  end

  function Webclient.show (component)
    local where     = component.where
    local data      = component.data
    local i18n      = component.i18n
    local template  = component.template
    local container = Webclient.jQuery ("#" .. where)
    local shown     = Webclient.shown [where]
    if data then
      data.locale = Webclient.locale
    end
    local replacer  = setmetatable ({}, {
      __index = function (_, key)
        if I18n.defines (i18n, key) then
          return i18n [key] % {}
        elseif data [key] then
          return tostring (data [key])
        else
          return nil
        end
      end
    })
    if shown and shown ~= loader.scheduler.running () then
      loader.scheduler.removethread (shown)
    end
    Webclient.shown [where] = loader.scheduler.running ()
    container:html (template % replacer)
  end

  function Webclient.template (name)
    local url = "/template/" .. name
    local result, err = loader.request (url, true)
    if not result then
      error (err)
    end
    return result
  end

  function Webclient.tojs (t)
    if type (t) ~= "table" then
      return t
    elseif #t ~= 0 then
      local result = Webclient.js.new (Webclient.window.Array)
      for i = 1, #t do
        result [result.length] = Webclient.tojs (t [i])
      end
      return result
    else
      local result = Webclient.js.new (Webclient.window.Object)
      for k, v in pairs (t) do
        assert (type (k) == "string")
        result [k] = Webclient.tojs (v)
      end
      return result
    end
  end

  function Webclient.init ()
    local Value       = loader.load "cosy.value"
    Webclient.library = loader.load "cosy.library"
    Webclient.storage = Webclient.window.sessionStorage
    local data        = Webclient.storage:getItem "cosy:client"
    Webclient.data    = Layer.new {
      name = "webclient",
      data = data ~= loader.js.null and Value.decode (data) or {},
    }
    Webclient.client  = assert (Webclient.library.connect (Webclient.origin, Webclient.data))
  end

  Webclient.js        = loader.js
  Webclient.window    = loader.js.global
  Webclient.document  = loader.js.global.document
  Webclient.navigator = loader.js.global.navigator
  Webclient.locale    = loader.js.global.navigator.language
  Webclient.origin    = loader.js.global.location.origin

  return Webclient

end
