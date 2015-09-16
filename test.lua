for value in _G.client.server.filter({
        iterator = [[return function (store)
          for k,user in store / "data" / "[^/]*" do
            if user.projectname == nil then
              coroutine.yield {lat = user.position.latitude , lng = user.position.longitude}
            end
          end
        end]]
      }) do
        if value.lat and value.lng then
          iframe.cluster (nil,value.lat,value.lng)
