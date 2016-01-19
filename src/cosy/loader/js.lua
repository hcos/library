if #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 to run."
end

return function (options)

  options = options or {}
  local loader = {}
  for k, v in pairs (options) do
    loader [k] = v
  end

  local global = _G or _ENV

  loader.home     = "/"
  loader.prefix   = "/"
  loader.js       = global.js
  loader.window   = loader.js.global
  loader.document = loader.js.global.document
  loader.screen   = loader.js.global.screen

  local modules  = setmetatable ({}, { __mode = "kv" })
  loader.request = function (url)
    local request = loader.js.new (loader.window.XMLHttpRequest)
    request:open ("GET", url, false)
    request:send (nil)
    if request.status == 200 then
      return request.responseText, request.status
    else
      return nil , request.status
    end
  end
  table.insert (package.searchers, 2, function (name)
    local url = "/lua/" .. name
    local result, err
    result, err = loader.request (url)
    if not result then
      error (err)
    end
    return load (result, url)
  end)
  loader.require = require
  loader.load    = function (name)
    if modules [name] then
      return modules [name]
    end
    local module   = loader.require (name) (loader) or true
    modules [name] = module
    return module
  end

  loader.coroutine = loader.require "coroutine.make" ()
  loader.logto     = true
  loader.scheduler = {
    _running  = nil,
    waiting   = {},
    ready     = {},
    blocked   = {},
    coroutine = loader.coroutine,
    timeout   = {},
  }
  function loader.scheduler.running ()
    return loader.scheduler._running
  end
  function loader.scheduler.addthread (f, ...)
    local co = loader.scheduler.coroutine.create (f)
    loader.scheduler.ready [co] = {
      parameters = { ... },
    }
    if loader.scheduler.co and coroutine.status (loader.scheduler.co) == "suspended" then
      coroutine.resume (loader.scheduler.co)
    end
  end
  function loader.scheduler.block (co)
    loader.scheduler.blocked [co] = true
  end
  function loader.scheduler.release (co)
    loader.scheduler.blocked [co] = nil
  end
  function loader.scheduler.sleep (time)
    time = time or -math.huge
    local co = loader.scheduler.running ()
    if time > 0 then
      loader.scheduler.timeout [co] = loader.window:setTimeout (function ()
        loader.window:clearTimeout (loader.scheduler.timeout [co])
        loader.scheduler.waiting [co] = nil
        loader.scheduler.ready   [co] = true
        if coroutine.status (loader.scheduler.co) == "suspended" then
          coroutine.resume (loader.scheduler.co)
        end
      end, time * 1000)
    end
    if time ~= 0 then
      loader.scheduler.waiting [co] = true
      loader.scheduler.ready   [co] = nil
      loader.scheduler.coroutine.yield ()
    end
  end
  function loader.scheduler.wakeup (co)
    loader.window:clearTimeout (loader.scheduler.timeout [co])
    loader.scheduler.waiting [co] = nil
    loader.scheduler.ready   [co] = true
    coroutine.resume (loader.scheduler.co)
  end
  function loader.scheduler.loop ()
    while true do
      for to_run, t in pairs (loader.scheduler.ready) do
        if not loader.scheduler.blocked [to_run] then
          if loader.scheduler.coroutine.status (to_run) == "suspended" then
            loader.scheduler._running = to_run
            local ok, err = loader.scheduler.coroutine.resume (to_run, type (t) == "table" and table.unpack (t.parameters))
            if not ok then
              loader.window.console:log (err)
            end
          end
          if loader.scheduler.coroutine.status (to_run) == "dead" then
            loader.scheduler.waiting [to_run] = nil
            loader.scheduler.ready   [to_run] = nil
          end
        end
      end
      if  not next (loader.scheduler.ready  )
      and not next (loader.scheduler.waiting)
      and not next (loader.scheduler.blocked) then
        loader.scheduler.co = nil
        break
      else
        local runnable = 0
        for k in pairs (loader.scheduler.ready) do
          if not loader.scheduler.blocked [k] then
            runnable = runnable + 1
            break
          end
        end
        if runnable == 0 then
          loader.scheduler.co = coroutine.running ()
        else
          coroutine.yield ()
        end
      end
    end
  end

  loader.load "cosy.string"

  return loader

end
