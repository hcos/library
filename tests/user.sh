#! /bin/bash

passwords=$(mktemp)
echo "password" >> ${passwords}
echo "password" >> ${passwords}

#echo "Stopping daemon:"
#./cosy.lua daemon:stop --force
#echo "Stopping server:"
#./cosy.lua server:stop  --force
#echo "Starting server:"
#./cosy.lua server:start --force --clean
echo "Printing available methods:"
./cosy.lua
echo "Server information:"
./cosy.lua server:information
echo "Terms of Service:"
./cosy.lua server:tos
echo "Creating user alinard:"
cat ${passwords} | ./cosy.lua user:create alban.linard@gmail.com alinard
echo "Failing at creating user alban:"
cat ${passwords} | ./cosy.lua user:create alban.linard@gmail.com alban
echo "Creating user alban:"
cat ${passwords} | ./cosy.lua user:create jiahua.xu16@gmail.com alban
echo "Authenticating user alinard:"
cat ${passwords} | ./cosy.lua user:authenticate alinard
echo "Authenticating user alban:"
cat ${passwords} | ./cosy.lua user:authenticate alban
echo "Updating user alban:"
./cosy.lua user:update --name="Alban Linard" --email=alban.linard@lsv.ens-cachan.fr
echo "Sending validation again:"
./cosy.lua user:send-validation
echo "Showing user alban:"
./cosy.lua user:information alban
echo "Deleting user alban:"
./cosy.lua user:delete
echo "Failing at authenticating user alban:"
cat ${passwords} | ./cosy.lua user:authenticate alban
echo "Authenticating user alinard:"
cat ${passwords} | ./cosy.lua user:authenticate alinard
echo "Creating project"
./cosy.lua project:create dd
for type in formalism model service execution scenario
do
  echo "Creating ${type} in project"
  ./cosy.lua ${type}:create instance-${type} alinard/dd
done
echo "Iterating over users"
./cosy.lua server:filter 'return function (store)
    for user in store / "data" * ".*" do
      coroutine.yield (user)
    end
  end'
echo "Iterating over projects"
./cosy.lua server:filter 'return function (store)
    for project in store / "data" * ".*" * ".*" do
      coroutine.yield (project)
    end
  end'
echo "Deleting project"
./cosy.lua project:delete alinard/dd
echo "Deleting user alinard:"
./cosy.lua user:delete

rm ${passwords}
