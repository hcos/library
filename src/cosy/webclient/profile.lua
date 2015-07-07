local js = _G.js
local window = _G.window
local location = js.global.location
local loader    = require (location.origin .. "/lua/cosy.loader")

local profile = function  ()
  local client = _G.client
  local value   = require "cosy.value"
  local co = coroutine.running ()
  local storage = js.global.sessionStorage
  local token = storage:getItem("cosytoken")
  js.global.document:getElementById("content-wrapper").innerHTML = loader.loadhttp ( "/html/profile.html")

  local result, err = client.user.update {
    authentication = token
    }
  if result then
  js.global.document:getElementById("pusername").innerHTML = result.username
  js.global.document:getElementById("email").value = result.email
    for _, key in ipairs { "name", "organization", "homepage", "locale" } do
      if result [key] then
        js.global.document:getElementById(key).value  = result [key]
      end
    end
    if (result.avatar) then
      js.global.document:getElementById("img").src = 'data:image/png;base64,'..result.avatar
    end

    if result.position.city then
      js.global.document:getElementById("city").value = result.position.city
    end
    if result.position.country_code then
      js.global.document:getElementById("country").value = result.position.country_code
    end
  else
    print ( value.expression (err))
  end
  js.global.document:getElementById("update").onclick = function()
    window:jQuery('#error'):hide()
    window:jQuery('#success'):hide()
    window:jQuery('.overlay'):show()
    coroutine.resume(co,"update")
    return false
  end
  js.global.document:getElementById("avatar").onchange = function(evt)
    local tgt = evt.target or window.event.srcElement
    local files = tgt.files
    if js.global.FileReader and files and #files > 0 then
      local fr = js.new(js.global.FileReader);
      fr.onload = function ()
        js.global.document:getElementById("img").src = fr.result;
      end
      fr:readAsDataURL(files[0]);
    end
  end

  local ok = true
  while ok do
    local event = coroutine.yield ()
    if event == "update" then

      local updatedata = {
        authentication = token,
        avatar         = nil,
        email          = nil,
        homepage       = nil,
        organization   = nil,
        name           = nil,
        locale         = nil,
        position       = nil,
      }
      updatedata.email  = js.global.document:getElementById("email").value
      for _, key in ipairs { "name", "organization", "homepage", "locale" } do
        if js.global.document:getElementById(key).value  ~= "" then
          updatedata [key] = js.global.document:getElementById(key).value
        end
      end
      local el = js.global.document:getElementById("country")
      local country = el.options[el.selectedIndex].text
      updatedata.position = {
            city = js.global.document:getElementById("city").value,
            country_code =  js.global.document:getElementById("country").value,
            country =  country  ,
            latitude  = "",
            longitude = "",
            }
      local file = js.global.document:getElementById('avatar').files[0]
      if file ~= nil then
        local xmlHttpRequest = js.new(window.XMLHttpRequest)
        xmlHttpRequest:open("POST", '/upload', false)
        xmlHttpRequest.onreadystatechange = function ()
          if xmlHttpRequest.readyState == 4 then
            if xmlHttpRequest.status == 200 then
              updatedata.avatar = xmlHttpRequest:getResponseHeader("Cosy-Avatar")
            end
          end
        end
        xmlHttpRequest:setRequestHeader("Content-Type", file.type)
        xmlHttpRequest:send(file)
      end
      result, err = client.user.update (updatedata)
      window:jQuery('.overlay'):hide()
      if result then
        window:jQuery('#success #message'):html("User Profile Updated")
        window:jQuery('#success'):show()
        if result.avatar then
          window:jQuery("#user-image-s"):attr("src", 'data:image/png;base64,'..result.avatar)
          window:jQuery("#user-image-b"):attr("src", 'data:image/png;base64,'..result.avatar)
        end
        if result.name then
          window:jQuery("#user-name"):html(result.name)
        end
      else
        window:jQuery('#error #message'):html(err.message)
        window:jQuery('#error'):show()
        if err.reasons then
          for i = 1, #err.reasons do
            local reason = err.reasons [i]
            if reason.parameter == "username" then
              window:jQuery('#usererror'):html(reason.message)
              window:jQuery('#usererror'):show()
              window:jQuery('#userdiv'):addClass("has-error")
            elseif reason.parameter == "email" then
              window:jQuery('#emailerror'):html(reason.message)
              window:jQuery('#emailerror'):show()
              window:jQuery('#emaildiv'):addClass("has-error")
            end
          end
        end
      end
    end
  end
end

local co = coroutine.create (profile)
coroutine.resume (co)
