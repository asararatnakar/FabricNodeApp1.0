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
VALUE="VAL123" ; ./quicktest.sh invoke $VALUE && sleep 5 && ./quicktest.sh query $VALUE

verifyResult $?

docker stop peer0.org1.example.com
decor
VALUE="VAL234" ; ./quicktest.sh invoke $VALUE && sleep 5 && ./quicktest.sh query $VALUE

verifyResult $?