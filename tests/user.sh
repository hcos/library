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
cat ${passwords} | ./cosy.lua user:create jiahua.xu16@gmail.com jiahua
echo "Authenticating user alinard:"
cat ${passwords} | ./cosy.lua user:authenticate alinard
echo "Authenticating user alban:"
cat ${passwords} | ./cosy.lua user:authenticate jiahua
echo "Updating user alban:"
./cosy.lua user:update --name="Alban Linard" --username=alban --email=alban.linard@lsv.ens-cachan.fr
echo "Sending validation again:"
./cosy.lua user:send-validation
echo "Showing user alban:"
./cosy.lua user:information alban

exit 1

echo "Deleting user alban:"
./cosy.lua user:delete
echo "Failing at authenticating user alban:"
cat ${passwords} | ./cosy.lua user:authenticate alban
echo "Authenticating user alinard:"
cat ${passwords} | ./cosy.lua user:authenticate alinard
echo "Creating project"
./cosy.lua project:create dd
echo "Delete project"
./cosy.lua project:delete alinard/dd
echo "Deleting user alinard:"
./cosy.lua user:delete

rm ${passwords}
