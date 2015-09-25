#! /bin/bash

./cosy.lua server:filter "return function (store) for i = 1, 10 do coroutine.yield (i, i) end end"
./cosy.lua server:filter "return function (store) for i = 1, 10 do coroutine.yield (i, i) end; error 'abcd' end"
./cosy.lua server:filter 'return function (store)
    for user in store / "data" * ".*" do
      coroutine.yield (user)
    end
  end'
./cosy.lua server:filter 'return function (store)
    for user in store / "data" * "alinard" do
      coroutine.yield (user)
    end
  end'
