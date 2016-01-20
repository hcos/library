return function (loader)

  local I18n      = loader.load "cosy.i18n"
  local Scheduler = loader.load "cosy.scheduler"
  local Webclient = loader.load "cosy.webclient"
  local Value     = loader.load "cosy.value"

  local i18n = I18n.load {
    "cosy.webclient.cli",
  }
  i18n._locale = Webclient.window.navigator.language

  local Cli = {
    template = {},
  }
  Cli.template.main = Webclient.template "cosy.webclient.cli"

  return function ()
    local component = {
      where    = "main",
      template = Cli.template.main,
      data     = {},
      i18n     = i18n,
    }
    Webclient.run (function ()
      local info = Webclient.client.server.information ()
      local port = Webclient.window.location.search:match "port=(%d+)"
      local need_captcha  = Webclient.window.location.search:match "captcha=true"
      local need_position = Webclient.window.location.search:match "position=true"
      component.data.need_captcha  = need_captcha
      component.data.need_position = need_position
      Webclient.show (component)
      local position, captcha
      local function activate ()
        if  (not need_position or (need_position and position))
        and (not captcha       or (need_captcha  and captcha ))
        then
          Webclient.window:jQuery "#accept":removeClass "disabled"
          Webclient.window:jQuery "#accept":addClass    "active"
        end
      end
      if need_position then
        local function locationpicker ()
          Webclient.window:jQuery "#position":locationpicker (Webclient.tojs {
            location     = position,
            radius       = 0,
            inputBinding = {
              locationNameInput = Webclient.window:jQuery "#address",
            },
            enableAutocomplete = true,
            onchanged          = function ()
              local location = Webclient.window:jQuery "#position":locationpicker "map".location
              position = {
                address   = location.formattedAddress,
                latitude  = location.latitude,
                longitude = location.longitude,
              }
              activate ()
            end,
            oninitialized      = function ()
              local location = Webclient.window:jQuery "#position":locationpicker "map".location
              position = {
                address   = location.formattedAddress,
                latitude  = location.latitude,
                longitude = location.longitude,
              }
              activate ()
            end,
          })
        end
        if Webclient.navigator.geolocation then
          Webclient.navigator.geolocation:getCurrentPosition (function (_, p)
            position = {
              latitude  = p.coords.latitude,
              longitude = p.coords.longitude,
            }
            activate ()
            locationpicker ()
          end, function ()
            locationpicker ()
          end)
        else
          locationpicker ()
        end
      end
      if need_captcha then
        local id
        id = Webclient.window.grecaptcha:render ("captcha", Webclient.tojs {
          sitekey  = info.captcha,
          callback = function ()
            captcha = Webclient.window.grecaptcha:getResponse (id)
            activate ()
          end,
        })
      end
      Webclient.document:getElementById "accept".onclick = function ()
        Webclient.run (function ()
          local wsurl = "ws://127.0.0.1:{{{port}}}/" % { port = port }
          local ws    = Webclient.js.new (Webclient.window.WebSocket, wsurl, "cosy-cli")
          ws.onopen = function ()
            ws:send (Value.expression {
              captcha  = captcha,
              position = position,
            })
            ws:close ()
            Webclient.window:close ()
          end
        end)
        return false
      end
      Scheduler.sleep (-math.huge)
    end)
  end

end
