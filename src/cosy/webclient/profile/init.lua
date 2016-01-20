return function (loader)

  local I18n          = loader.load "cosy.i18n"
  local Scheduler     = loader.load "cosy.scheduler"
  local Webclient     = loader.load "cosy.webclient"

  local i18n = I18n.load {
    "cosy.webclient.profile",
    "cosy.webclient.authentication",
    "cosy.client",
  }
  i18n._locale = Webclient.window.navigator.language

  local Profile = {
    template = {},
  }
  Profile.template.show = Webclient.template "cosy.webclient.profile.show"
  Profile.template.edit = Webclient.template "cosy.webclient.profile.edit"

  return function (options)
    Webclient.run (function ()
      local component = {
        where    = options.where,
        template = nil,
        data     = {},
        i18n     = i18n,
      }
      while true do
        local user = Webclient.client.user.authentified_as {}
        options.username = options.username or user.identifier
        if user and options.username == user.identifier then

          local info = Webclient.client.user.update {}
          local position
          local avatar

          local function check ()
            Webclient.window:jQuery "#accept":addClass    "disabled"
            Webclient.window:jQuery "#accept":removeClass "active"
            local email        = Webclient.document:getElementById "email".value
            local name         = Webclient.document:getElementById "name".value
            local organization = Webclient.document:getElementById "organization".value
            local homepage     = Webclient.document:getElementById "homepage".value
            local password     = Webclient.document:getElementById "password-1".value
            local result, err  = Webclient.client.user.update ({
              email        = email ~= info.email and email        or nil,
              avatar       = avatar              and avatar       or nil,
              name         = name         ~= ""  and name         or nil,
              organization = organization ~= ""  and organization or nil,
              homepage     = homepage     ~= ""  and homepage     or nil,
              password     = password     ~= ""  and password     or nil,
              position     = position            and position     or nil,
              locale       = Webclient.window.navigator.language,
            }, true)
            for _, x in ipairs { "avatar", "name", "organization", "email", "homepage", "position", "password-1", "password-2" } do
              Webclient.window:jQuery ("#" .. x .. "-group"):removeClass "has-error"
              Webclient.window:jQuery ("#" .. x .. "-error"):html ("")
              if Webclient.document:getElementById (x).value ~= (info [x] or "") then
                Webclient.window:jQuery ("#" .. x .. "-group"):addClass "has-success"
              end
            end
            if position then
              Webclient.window:jQuery ("#position-group"):addClass "has-success"
            end
            local passwords = {
              Webclient.document:getElementById "password-1".value,
              Webclient.document:getElementById "password-2".value,
            }
            if passwords [1] ~= passwords [2] then
              Webclient.window:jQuery "#password-group":addClass "has-error"
              local text = i18n ["argument:password:nomatch"] % {}
              Webclient.window:jQuery "#password-error":html (text)
              result = false
            elseif passwords [1] ~= "" then
              Webclient.window:jQuery "#password-group":addClass "has-success"
              Webclient.window:jQuery "#password-error":html ("")
            end
            if result then
              Webclient.window:jQuery "#accept":removeClass "disabled"
              Webclient.window:jQuery "#accept":addClass    "active"
              return true
            elseif err then
              for _, reason in ipairs (err.reasons or {}) do
                Webclient.window:jQuery ("#" .. reason.key .. "-group"):addClass "has-error"
                Webclient.window:jQuery ("#" .. reason.key .. "-error"):html (reason.message)
              end
              return false
            end
          end

          local co = Scheduler.running ()
          component.template     = Profile.template.edit
          component.data         = info
          component.data.address = info.position and "{{{city}}}, {{{country}}}" % info.position
          Webclient.show (component)
          local params = {
            location     = info.position,
            radius       = 0,
            inputBinding = {
              locationNameInput = Webclient.window:jQuery "#address",
            },
            enableAutocomplete = true,
            onchanged          = function (_, current)
              position = {
                address   = Webclient.document:getElementById "address".value,
                latitude  = current.latitude,
                longitude = current.longitude,
              }
              Webclient.run (check)
            end,
          }
          Webclient.window:jQuery "#position":locationpicker (Webclient.tojs (params))
          for _, x in ipairs { "name", "organization", "homepage", "email", "password-1", "password-2" } do
            Webclient.document:getElementById (x).onblur = function ()
              Webclient.run (check)
            end
          end
          Webclient.document:getElementById "avatar-button".onchange = function ()
            local reader = Webclient.js.new (Webclient.window.FileReader)
            reader.onload = function ()
              avatar = reader.result:match "base64,(.*)"
              Webclient.document:getElementById "avatar".src = "data:image/*;base64," .. avatar
              Webclient.run (check)
            end
            local button = Webclient.document:getElementById "avatar-button"
            reader:readAsDataURL (button.files [0])
          end
          Webclient.document:getElementById "accept".onclick = function ()
            Scheduler.wakeup (co)
            return false
          end
          Webclient.document:getElementById "delete".onclick = function ()
            Webclient.window.bootbox:confirm (i18n ["profile:delete"] % {}, function (result)
              if result ~= Webclient.js.null then
                Webclient.run (function ()
                  assert (Webclient.client.user.delete {})
                  Webclient.window:jQuery "#log-out":click ()
                end)
              end
            end)
            return false
          end
          Scheduler.sleep (-math.huge)
          local email        = Webclient.document:getElementById "email".value
          local name         = Webclient.document:getElementById "name".value
          local organization = Webclient.document:getElementById "organization".value
          local homepage     = Webclient.document:getElementById "homepage".value
          local password     = Webclient.document:getElementById "password-1".value
          assert (Webclient.client.user.update {
            email        = email ~= info.email and email        or nil,
            avatar       = avatar              and avatar       or nil,
            name         = name         ~= ""  and name         or nil,
            organization = organization ~= ""  and organization or nil,
            homepage     = homepage     ~= ""  and homepage     or nil,
            password     = password     ~= ""  and password     or nil,
            position     = position            and position     or nil,
            locale       = Webclient.window.navigator.language,
          })

        else

          local info = Webclient.client.user.information {
            user = options.username,
          }
          component.template      = Profile.template.show
          component.data          = info
          component.data.address  = info.position and "{{{city}}}, {{{country}}}" % info.position
          Webclient.show (component)
          local params = {
            location     = info.position,
            radius       = 0,
          }
          Webclient.window:jQuery "#position":locationpicker (Webclient.tojs (params))
          Scheduler.sleep (-math.huge)

        end
      end
    end)
  end

end
