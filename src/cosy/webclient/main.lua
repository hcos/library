return function (loader)
  local Value = loader.load "cosy.value"

  local Main = {}

  local function show_users ()
    local result, err = loader.client.server.filter {
      iterator = [[
        return function (coroutine, store)
          for user in store / "data" * ".*" do
            if user.position then
              coroutine.yield {
                latitude  = user.position.latitude,
                longitude = user.position.longitude,
              }
            end
          end
        end
      ]]
    }
    if result then
      local iframe = loader.document:getElementById "map".contentWindow
      for value in result do
        iframe.cluster (nil, value.latitude, value.longitude)
      end
      iframe.groupcluster ()
    else
      print (err.message, Value.encode (err))
    end
  end

  function Main.init ()
    local serverinfo = assert (loader.client.server.information ())
    local userinfo   = assert (loader.client.user.authentified_as {})
    local username = userinfo and userinfo.username
    loader.document:getElementById "content-wrapper".innerHTML = (loader.request "/html/main.html") % serverinfo
    if username then
      loader.document:getElementById "navbar-login".innerHTML = loader.request "/html/logoutnavbar.html"
      loader.document:getElementById "user-in".innerHTML = username
      userinfo = loader.client.user.update {}
      if userinfo.name then
        loader.document:getElementById "user-name".innerHTML = userinfo.name
      end
      if userinfo.lastseen then
        loader.document:getElementById "user-last".innerHTML = os.date ("%d/%m/%Y %H:%M:%S", userinfo.lastseen)
      end
      if userinfo.avatar then
        loader.document:getElementById "user-image-s".src = "data:image/png;base64," .. userinfo.avatar
        loader.document:getElementById "user-image-b".src = "data:image/png;base64," .. userinfo.avatar
      else
        loader.document:getElementById "user-image-s".src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQYV2P4DwABAQEAWk1v8QAAAABJRU5ErkJggg=="
        loader.document:getElementById "user-image-b".src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQYV2P4DwABAQEAWk1v8QAAAABJRU5ErkJggg=="
      end
      loader.document:getElementById "logout-button".onclick = function ()
        loader.storage:removeItem "cosy:client"
        loader.window.location.href = "/"
        return false
      end
      loader.document:getElementById "profile-button".onclick = function ()
        loader.load "cosy.webclient.profile"
        return false
      end
    else
      local Auth = loader.load "cosy.webclient.auth"
      loader.document:getElementById "navbar-login".innerHTML = loader.request "/html/loginnavbar.html"
      loader.document:getElementById "login-button".onclick = function ()
        loader.scheduler.addthread (Auth.login)
        return false
      end
      loader.document:getElementById "signup-button".onclick = function ()
        loader.scheduler.addthread (Auth.register)
        return false
      end
    end
    local map = loader.document:getElementById "map"
    map.onload = function ()
      loader.scheduler.addthread (show_users)
    end
  end

  Main.init ()

  -- Update server information regularly:
  loader.scheduler.addthread (function ()
    while true do
      loader.scheduler.sleep (10)
      local serverinfo = assert (loader.client.server.information ())
      for k, v in pairs (serverinfo) do
        if k:match "^#" then
          local part = loader.document:getElementById (k)
          if part ~= loader.js.null then
            part.innerHTML = tostring (v)
          end
        end
      end
    end
  end)

end
