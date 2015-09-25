#! /bin/bash

./cosy.lua server:filter "return function (store) for i = 1, 10 do coroutine.yield (i, i) end end"
./cosy.lua server:filter "return function (store) for i = 1, 10 do coroutine.yield (i, i) end; error 'abcd' end"
./cosy.lua server:filter 'return function (store)
    for key, user in store / "data" / ".*" do
      coroutine.yield { key = key, name = user.username, latitude = user.position.latitude, longitude = user.position.longitude, 1, 2, 3}
    end
  end'
./cosy.lua server:filter 'return function (store)
    for key, user in store / "data" / "alinard" do
      coroutine.yield { key = key, name = user.username, }
    end
  end'
