local Loader = require "cosy.loader"

Loader.loadhttp = function (url)
  local request = _G.js.new (_G.window.XMLHttpRequest)
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
  result, err = Loader.loadhttp (url)
  if not result then
    error (err)
  end
  return load (result, url)
end)

Loader.hotswap = require "hotswap" .new {}

Loader.configure ()

return Loader
