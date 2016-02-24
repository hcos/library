return function (loader)

  local I18n          = loader.load "cosy.i18n"
  local Webclient     = loader.load "cosy.webclient"

  local i18n = I18n.load {
    "cosy.webclient.dashboard",
  }
  i18n._locale = Webclient.window.navigator.language

  local Dashboard = {
    template = {},
  }
  Dashboard.__index = Dashboard
  Dashboard.template.anonymous = Webclient.template "cosy.webclient.dashboard.anonymous"
  Dashboard.template.user      = Webclient.template "cosy.webclient.dashboard.user"

  local function show_map ()
    Dashboard.map = Webclient.js.new (
      Webclient.window.google.maps.Map,
      Webclient.document:getElementById "map",
      Webclient.tojs {
        zoom   = 1,
        center = {
          lat = 0,
          lng = 0,
        },
        mapTypeId         = Webclient.window.google.maps.MapTypeId.SATELLITE,
        streetViewControl = false,
      })
    local iterator = Webclient.client.server.filter {
      iterator = [[
        return function (coroutine, store)
          for user in store / "data" * ".*" do
            coroutine.yield (user)
          end
        end
      ]],
    }
    for user in iterator do
      Webclient.js.new (Webclient.window.google.maps.Marker, Webclient.tojs {
        position = {
          lat = user.position and user.position.latitude  or 44.7328221,
          lng = user.position and user.position.longitude or  4.5917742,
        },
        map       = Dashboard.map,
        draggable = false,
        animation = Webclient.window.google.maps.Animation.DROP,
        icon      = user.avatar and "data:image/png;base64," .. user.avatar.icon or nil,
        title     = user.identifier,
      })
    end
  end

  function Dashboard.anonymous ()
    Dashboard.map = nil
    local info = Webclient.client.server.information {}
    local data = {}
    for k, v in pairs (info) do
      local key = k:match "^#(.*)$"
      if key then
        data ["count-" .. key] = i18n ["dashboard:count-" .. key] % { count = v }
      else
        data [k] = v
      end
    end
    Webclient.show {
      where    = "main",
      template = Dashboard.template.anonymous,
      data     = data,
      i18n     = i18n,
    }
    if not Dashboard.map then
      show_map ()
    end
  end

  function Dashboard.user (user)
    local projects = Webclient.client.server.filter {
      iterator = [[return function (coroutine, store)
          for project in store / "data" / "{{{user}}}" * ".*" do
            coroutine.yield (project)
          end
        end
      ]] % {
        user = user.id,
      },
    }
    local data = {
      projects = {},
    }
    for project in projects do
      data.projects [#data.projects+1] = project
    end
    if #data.projects == 0 then
      data.projects = nil
    end
    Webclient.show {
      where    = "main",
      template = Dashboard.template.user,
      data     = data,
      i18n     = i18n,
    }
  end

  function Dashboard.__call ()
    Webclient (function ()
      while true do
        local user = Webclient.client.user.authentified_as {}
        if user.identifier then
          Dashboard.user (user)
        else
          Dashboard.anonymous ()
        end
      loader.scheduler.sleep (-math.huge)
      end
    end)
  end

  return setmetatable ({}, Dashboard)

end
