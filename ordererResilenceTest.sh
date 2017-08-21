#!/bin/bash -e
function decor(){
  printf "\n ======================================== \n"
  docker ps -a | grep orderer
  printf "\n ======================================== \n"
}

function verifyResult(){
    if [ $1 -eq 1 ]; then
      printf "\n!!!!!!!!!!!! TEST FAILED !!!!!!!!!!!! \n"
      exit 1
    fi
}

decor
VALUE="VALUE1" ; ./quicktest.sh invoke $VALUE && sleep 5 && ./quicktest.sh query $VALUE

verifyResult $?

docker stop orderer0.example.com
decor
VALUE="VALUE2" ; ./quicktest.sh invoke $VALUE && sleep 5 && ./quicktest.sh query $VALUE

verifyResult $?

docker stop orderer1.example.com
decor
VALUE="VALUE3" ; ./quicktest.sh invoke $VALUE && sleep 15 && ./quicktest.sh query $VALUE

verifyResult $?

docker start orderer0.example.com && sleep 5 && docker stop orderer2.example.com && sleep 5
decor
VALUE="VALUE4" ; ./quicktest.sh invoke $VALUE && sleep 15 && ./quicktest.sh query $VALUE

verifyResult $?

docker start orderer2.example.com && sleep 5 && docker stop orderer0.example.com && sleep 5 && docker stop orderer1.example.com
decor
VALUE="VALUE5" ; ./quicktest.sh invoke $VALUE && sleep 15 && ./quicktest.sh query $VALUE
verifyResult $?
