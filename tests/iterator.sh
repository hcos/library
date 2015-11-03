#! /bin/bash

if [ -z "$1" ]; then
  echo "usage: $0 path_to_cosy_script"
  echo "ex: $0 /home/cosy/bin/cosy"
  exit
else
  cosy="$1"
fi

"${cosy}" server:filter "return function (store) for i = 1, 10 do coroutine.yield (i, i) end end"
"${cosy}" server:filter "return function (store) for i = 1, 10 do coroutine.yield (i, i) end; error 'abcd' end"
"${cosy}" server:filter 'return function (store)
    for user in store / "data" * ".*" do
      coroutine.yield (user)
    end
  end'
"${cosy}" server:filter 'return function (store)
    for project in store / "data" * ".*" * ".*" do
      coroutine.yield (project)
    end
  end'
