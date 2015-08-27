#! /bin/bash

./cosy.lua server:filter "return function (yield, store) for i = 1, 10 do yield (i, i) end end"
./cosy.lua server:filter "return function (yield, store) for i = 1, 10 do yield (i, i) end; error 'abcd' end"
