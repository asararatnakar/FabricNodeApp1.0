#!/bin/bash

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Please Install 'jq' https://stedolan.github.io/jq/ to execute this script"
  echo
  exit 1
fi

echo "POST request Enroll user 'Jim' on Org1  ..."
echo
ORG1_TOKEN=$(curl -s -X POST \
  http://localhost:4000/users \
  -H "content-type: application/x-www-form-urlencoded" \
-d 'username=Jim&orgName=org1')
echo $ORG1_TOKEN
ORG1_TOKEN=$(echo $ORG1_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG1 token is $ORG1_TOKEN"
echo

function createchannel(){
  echo
  echo "POST request Create channel  ..."
  echo
  curl -s -X POST \
  http://localhost:4000/channels \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"channelName":"mychannel1",
	"channelConfigPath":"../artifacts/channel/mychannel1.tx",
	"configUpdate":false
  }'
  echo
  echo
  sleep 5
}

function joinchannel(){
  echo "POST request Join channel on Org1"
  echo
  curl -s -X POST \
  http://localhost:4000/channels/mychannel1/peers \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:7051","localhost:8051"]
  }'
  echo
  echo
}

function installcc(){
  echo "POST Install chaincode on Org1"
  echo
  curl -s -X POST \
  http://localhost:4000/chaincodes \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:7051","localhost:8051"],
	"chaincodeName":"mycc",
	"chaincodePath":"github.com/uniqueKeyValue",
	"chaincodeVersion":"v0"
  }'
  echo
  echo
}

function instantiatecc(){
  echo "POST instantiate chaincode on peer1 of Org1 on mychannel1"
  echo
  curl -s -X POST \
  http://localhost:4000/channels/mychannel1/chaincodes \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"chaincodeName":"mycc",
	"chaincodeVersion":"v0",
	"functionName":"init",
	"args":[""]
  }'
  echo
}
VALUE="ABCDEF"

function invokecc(){
  echo "POST invoke chaincode on peers of Org1"
  echo
  if [ ! -z "$1" ]; then
    VALUE="$1"
  fi

  TRX_ID=$(curl -s -X POST \
    http://localhost:4000/channels/mychannel1/chaincodes/mycc \
    -H "authorization: Bearer $ORG1_TOKEN" \
    -H "content-type: application/json" \
    -d "{
	\"peers\": [\"localhost:7051\", \"localhost:8051\"],
	\"fcn\":\"put\",
	\"args\":[\"org1\",\"$VALUE\"]
  }")
  echo "Transacton ID is $TRX_ID"
  export TRX_ID
  echo
  echo
}

function querycc(){
  echo "GET query chaincode on peer1 of Org1"
  echo
  if [ ! -z "$1" ]; then
    VALUE="$1"
  fi
  RESP=$(curl -s -X GET \
    "http://localhost:4000/channels/mychannel1/chaincodes/mycc?peer=peer1&fcn=get&args=%5B%22org1%22%5D" \
    -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json")
  printf "\nResponse is : $RESP"
  if [ "$RESP" == "$VALUE" ]; then
    printf "\n=============== TEST PASSED : $RESP ==  $VALUE =============== \n\n"
  else
    printf "\n!!!!!!!!!  TEST FAILED : $RESP !=  $VALUE !!!!!!!!!\n\n"
  fi
}

function sysQueries() {
  printf "\n\n #################### SYSTEM CHAINCODE QUERIES ######################\n\n"
  echo "GET query Block by blockNumber"
  echo
  curl -s -X GET \
  "http://localhost:4000/channels/mychannel1/blocks/1?peer=peer1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo
  echo

  echo "GET query Transaction by TransactionID"
  echo
  curl -s -X GET http://localhost:4000/channels/mychannel1/transactions/$TRX_ID?peer=peer1 \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo
  echo

  echo "GET query ChainInfo on mychannel1"
  echo
  curl -s -X GET \
  "http://localhost:4000/channels/mychannel1?peer=peer1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo

  echo "GET query Installed chaincodes"
  echo
  curl -s -X GET \
  "http://localhost:4000/chaincodes?peer=peer1&type=installed" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo
  echo

  echo "GET query Instantiated chaincodes on mychannel1"
  echo
  curl -s -X GET \
  "http://localhost:4000/chaincodes?peer=peer1&type=instantiated&channel=mychannel1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo
  echo

  echo "GET query Channels"
  echo
  curl -s -X GET \
  "http://localhost:4000/channels?peer=peer1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo
  echo

  echo "GET height of channel mychannel1"
  echo
  curl -s -X GET \
  "http://localhost:4000/channels/mychannel1/height?peer=peer1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
  echo
}

function allinone(){
  starttime=$(date +%s)
  createchannel
  joinchannel
  installcc
  instantiatecc
  invokecc
  querycc
  sysQueries
  printf "\nTotal execution time : $(($(date +%s)-starttime)) secs ...\n\n"
}

case "$1" in
  "create")
    createchannel
  ;;
  "join")
    joinchannel
  ;;
  "install")
    installcc
  ;;
  "instantiate")
    instantiatecc
  ;;
  "invoke")
    invokecc "$2"
  ;;
  "query")
    querycc "$2"
  ;;
  *)
    allinone
  ;;
esac
