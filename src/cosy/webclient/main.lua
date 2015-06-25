local location = js.global.location
loader    = require (location.origin .. "/lua/cosy.loader")

local function main()
  local lib      = require "cosy.library"
  client   = lib.connect (js.global.location.origin) 
  local storage = js.global.sessionStorage
  local token = storage:getItem("cosytoken")
  local user = storage:getItem("cosyuser") 
  local connected = false  
  local result, err = client.user.is_authentified  {
      authentication = token
    }
    
  if result and user == result.username and token ~= js.null then
    connected = true
  end
  
  if connected then
    js.global.document:getElementById("navbar-login").innerHTML = loader.loadhttp ( "/html/logoutnavbar.html")
    js.global.document:getElementById("user-in").innerHTML = user
    local result, err = client.user.update {
      authentication = token
    }
    if result.name then
      js.global.document:getElementById("user-name").innerHTML = result.name
    end
    if result.lastseen then
      js.global.document:getElementById("user-last").innerHTML = os.date('%d/%m/%Y %H:%M:%S', result.lastseen)
    end
    if result.avatar then
      js.global.document:getElementById("user-image-s").src = 'data:image/png;base64,'..result.avatar
      js.global.document:getElementById("user-image-b").src = 'data:image/png;base64,'..result.avatar
    else
      js.global.document:getElementById("user-image-s").src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQYV2P4DwABAQEAWk1v8QAAAABJRU5ErkJggg=="
      js.global.document:getElementById("user-image-b").src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVQYV2P4DwABAQEAWk1v8QAAAABJRU5ErkJggg=="
    end

    js.global.document:getElementById("logout-button").onclick = function()
      storage:removeItem("cosytoken")
      storage:removeItem("cosyuser")
      js.global.location.href = "/"
      return false
    end  
    js.global.document:getElementById("profile-button").onclick = function()
      require ("cosy.webclient.profile")  
      return false
    end    
  else
    local auth = require ("cosy.webclient.auth") 
    js.global.document:getElementById("navbar-login").innerHTML = loader.loadhttp ( "/html/loginnavbar.html")
    js.global.document:getElementById("login-button").onclick = function()
      coroutine.wrap(auth.login) ()
      return false
    end
    js.global.document:getElementById("signup-button").onclick = function()
      coroutine.wrap(auth.register) ()  
      return false
    end
  end
  
end

local co = coroutine.create (main)
coroutine.resume (co)
