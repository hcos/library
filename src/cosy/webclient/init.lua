return function (loader)

  local I18n      = loader.load "cosy.i18n"
  local Scheduler = loader.load "cosy.scheduler"
  local Layer     = loader.require "layeredata"

  local Webclient = {}

  Webclient.js        = loader.js
  Webclient.window    = loader.js.global
  Webclient.document  = loader.js.global.document
  Webclient.screen    = loader.js.global.screen
  Webclient.navigator = loader.js.global.navigator
  Webclient.locale    = Webclient.window.navigator.language

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

  function Webclient.show (component)
    local where     = component.where
    local data      = component.data
    local i18n      = component.i18n
    local template  = component.template
    local container = Webclient.document:getElementById (where)
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
    container.innerHTML = template % replacer
  end

  function Webclient.hide (component)
    local where     = component.where
    local container = Webclient.document:getElementById (where)
    container.innerHTML = ""
  end

  function Webclient.run (f)
    Scheduler.addthread (function ()
      xpcall (f, function (err)
        print ("error:", err)
        print (debug.traceback ())
      end)
    end)
  end

  function Webclient.template (name)
    local url = "/template/" .. name
    local result, err = loader.request (url, true)
    if not result then
      error (err)
    end
    return result
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
    Webclient.client  = Webclient.library.connect (Webclient.window.location.origin, Webclient.data)
  end

  Webclient.init ()

  return Webclient

end
