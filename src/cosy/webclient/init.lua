return function (loader)

  local I18n      = loader.load "cosy.i18n"
  local Scheduler = loader.load "cosy.scheduler"
  local Layer     = loader.require "layeredata"
  local locale    = loader.window.navigator.language

  local Webclient = {
    shown = setmetatable ({}, {
      __index = function (shown, k)
        local result = {}
        shown [k] = result
        return result
      end,
    }),
  }

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
    local container = loader.document:getElementById (where)
    local stack     = Webclient.shown [where]
    if #stack ~= 0 then
      local previous = stack [#stack]
      Scheduler.block (previous.co)
      previous.contents   = container.innerHTML
      container.innerHTML = ""
    end
    stack [#stack+1] = {
      co       = Scheduler.running (),
      contents = nil,
    }
    if data then
      data.locale = locale
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

  function Webclient.update (component)
    local where     = component.where
    local data      = component.data
    local i18n      = component.i18n
    local template  = component.template
    local container = loader.document:getElementById (where)
    local stack     = Webclient.shown [where]
    if #stack == 0 then
      return Webclient.show (component)
    end
    local current   = stack [#stack]
    if current.co ~= Scheduler.running () then
      return Webclient.show (component)
    end
    if data then
      data.locale = locale
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
    local container = loader.document:getElementById (where)
    local stack     = Webclient.shown [where]
    assert (#stack ~= 0)
    local current   = stack [#stack]
    local previous  = stack [#stack-1]
    stack [#stack]  = nil
    container.innerHTML = ""
    Scheduler.block (current.co)
    if previous then
      container.innerHTML = previous.contents
      Scheduler.release (previous.co)
    end
  end

  function Webclient.run (f)
    Scheduler.addthread (function ()
      xpcall (f, function (err)
        print ("error:", err)
        print (debug.traceback ())
      end)
    end)
  end

  local Value     = loader.load "cosy.value"
  loader.library  = loader.load "cosy.library"
  loader.storage  = loader.window.sessionStorage
  local data      = loader.storage:getItem "cosy:client"
  loader.data     = Layer.new {
    name = "webclient",
    data = data ~= loader.js.null and Value.decode (data) or {},
  }
  loader.client   = loader.library.connect (loader.window.location.origin, loader.data)

  Webclient.run (function ()
    while true do
      Scheduler.sleep (3600)
    end
  end)

  return Webclient

end
