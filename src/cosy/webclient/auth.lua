local loader    = require "cosy.loader"
local mainregister

local function mainlogin ()
local value   = require "cosy.value"
  local co = coroutine.running ()
  js.global.document:getElementById("content-wrapper").innerHTML = loader.loadhttp ( "/html/login.html")
  js.global.document:getElementById("signin").onclick = function()
    window:jQuery('#userdiv'):removeClass("has-error")
    window:jQuery('#error'):hide()
    window:jQuery('#usererror'):hide()
    coroutine.resume(co,"auth")
    return false
  end
  js.global.document:getElementById("register").onclick = function()
     coroutine.resume(co,"loadregister")
     return false
   end

  local ok = true
  while ok do
    local event = coroutine.yield ()
    if event == "auth" then
      local user  = js.global.document:getElementById("username").value
      local pass  = js.global.document:getElementById("pass").value
      local result, err = client.user.authenticate {
        user  = user,
        password   = pass,
      }
      js.global.console:log (result)

      if result then
        window:jQuery('#success #message'):html("User authentificated")
        window:jQuery('#success'):show()
        local storage = js.global.sessionStorage
        storage:setItem("cosytoken",result.authentication)
        storage:setItem("cosyuser",user)
        js.global.location.href = "/"
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
            end
          end
        end
      end
    elseif event == "loadregister" then
		ok = false
		mainregister()
    end
  end
end

mainregister = function  ()
local value   = require "cosy.value"
  local co = coroutine.running ()
  js.global.document:getElementById("content-wrapper").innerHTML = loader.loadhttp ( "/html/register.html")
  js.global.document:getElementById("register").onclick = function()
    window:jQuery('#userdiv'):removeClass("has-error")
    window:jQuery('#error'):hide()
    window:jQuery('#usererror'):hide()
    window:jQuery('#emaildiv'):removeClass("has-error")
    window:jQuery('#error'):hide()
    window:jQuery('#emailerror'):hide()
    window:jQuery('#passdiv'):removeClass("has-error")
    window:jQuery('#error'):hide()
    window:jQuery('#passerror'):hide()
    local pass = js.global.document:getElementById("pass").value
    local passret = js.global.document:getElementById("repass").value
    if pass ~= passret then
      window:jQuery('#passerror'):html("Password incorrect")
      window:jQuery('#passerror'):show()
      window:jQuery('#passdiv'):addClass("has-error")
      return false
    end
     
     coroutine.resume(co,"register")
     return false
   end
  js.global.document:getElementById("login").onclick = function()
     coroutine.resume(co,"loadlogin")
     return false
  end
  js.global.document:getElementById("term").onclick = function()
     coroutine.resume(co,"tos")
     return false
  end
   js.global.document:getElementById("termcheck").onclick = function()
      if (window:jQuery("#termcheck"):is(':checked')) then
        window:jQuery('#register'):removeAttr('disabled');
      else
          window:jQuery('#register'):attr('disabled', 'disabled');
      end
  end

 -- connect ()
  local ok = true
  while ok do
    local event = coroutine.yield ()
    if event == "register" then
      local user  = js.global.document:getElementById("username").value
      local pass  = js.global.document:getElementById("pass").value
      local email  = js.global.document:getElementById("email").value
      local tostext  = client.server.tos ()
    
      local result, err = client.user.create {
      username   = user,
      password   = pass,
      email      = email ,
      tos_digest = tostext.tos_digest:upper (),
      locale     = "en",
      }

     if result then
        window:jQuery('#success #message'):html("User Created")
        window:jQuery('#success'):show()
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
      --print ("user", value.expression (err))
    elseif event == "loadlogin" then
      ok = false
	  mainlogin()
    elseif event == "tos" then
      print ("user", event)
      local tostext  = client.server.tos ()
     -- js.global.document:getElementById("modal-body").innerHTML = tostext.tos  
      window:jQuery('#modal-body'):html(tostext.tos:gsub("\n","<br>"))
      window:jQuery("#terms"):modal()
    end
  end
end

return {
  login    = mainlogin,
  register = mainregister,
}
