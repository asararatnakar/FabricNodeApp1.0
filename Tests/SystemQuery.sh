#!/bin/bash

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Please Install 'jq' https://stedolan.github.io/jq/ to execute this script"
	echo
	exit 1
fi
starttime=$(date +%s)

echo "POST request Enroll user 'Jim' on Org1  ..."
echo
ORG1_TOKEN=$(curl -s -X POST \
  http://localhost:3000/users \
  -H "content-type: application/x-www-form-urlencoded" \
  -d 'username=Jim&orgName=org1')
echo $ORG1_TOKEN
ORG1_TOKEN=$(echo $ORG1_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG1 token is $ORG1_TOKEN"
echo

echo "POST request Enroll user 'Barry' on Org2 ..."
echo
ORG2_TOKEN=$(curl -s -X POST \
  http://localhost:3000/users \
  -H "content-type: application/x-www-form-urlencoded" \
  -d 'username=Barry&orgName=org2')
echo $ORG2_TOKEN
ORG2_TOKEN=$(echo $ORG2_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG2 token is $ORG2_TOKEN"
echo

#echo "GET query Block by blockNumber $i" > block2.txt
#echo "" >> block2.txt
#curl -s -X GET \
#  http://localhost:3000/channels/mychannel0/blocks/3?peer=peer1 \
#  -H "authorization: Bearer $ORG1_TOKEN" \
#  -H "content-type: application/json" >&block2.txt
#TRX_COUNT=$(jq ".data.data | length" block2.txt)
#echo "##################$TRX_COUNT#################"
#echo ">>>>>>>>>>>>>>>>>$TRX_COUNT<<<<<<<<<<<<<<<<<<"
#TRX_COUNT=` expr TRX_COUNT / 2 `
#TRX_COUNT=$(($TRX_COUNT / 2))
#echo "Total transactions for the block 3 are $TRX_COUNT"
#exit
#echo "GET query Block by blockNumber"
#echo
#curl -s -X GET \
#  "http://localhost:3000/channels/mychannel0/blocks/1?peer=peer1" \
#  -H "authorization: Bearer $ORG1_TOKEN" \
#  -H "content-type: application/json"
#echo
#echo

#echo "GET query Transaction by TransactionID"
#echo
#curl -s -X GET http://localhost:3000/channels/mychannel0/transactions/$TRX_ID?peer=peer1 \
#  -H "authorization: Bearer $ORG1_TOKEN" \
#  -H "content-type: application/json"
#echo
#echo

echo "GET query ChainInfo on mychannel0"
echo
curl -s -X GET \
  "http://localhost:3000/channels/mychannel0?peer=peer1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
echo

echo
HEIGHT=$(curl -s -X GET \
  "http://localhost:3000/channels/mychannel0/height?peer=peer1" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json")
echo
printf "\nChannel mychannel0 Height on peer1/ORG1 is $HEIGHT\n\n"
echo
HEIGHT=$(curl -s -X GET \
  "http://localhost:3000/channels/mychannel0/height?peer=peer2" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json")
echo
printf "\nChannel mychannel0 Height on peer2/ORG1 is $HEIGHT\n\n"
echo
HEIGHT=$(curl -s -X GET \
  "http://localhost:3000/channels/mychannel0/height?peer=peer1" \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json")
echo
printf "\nChannel mychannel0 Height on peer1/ORG2 is $HEIGHT\n\n"
echo
HEIGHT=$(curl -s -X GET \
  "http://localhost:3000/channels/mychannel0/height?peer=peer2" \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json")
echo
printf "\nChannel mychannel0 Height on peer2/ORG2 is $HEIGHT\n\n"
echo
#exit
TOTAL_TRX=0
for (( i=0;i<$HEIGHT;i=$i+1 ))
do
curl -s -X GET \
  http://localhost:3000/channels/mychannel0/blocks/$i?peer=peer1 \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" > block1.txt
cat block1.txt >> block.txt
TRX_COUNT=$(jq ".data.data | length" block1.txt)
TRX_COUNT=$(($TRX_COUNT))
TOTAL_TRX=` expr $TOTAL_TRX + $TRX_COUNT `
TX_ID=$(jq ".data.data[0].payload.header.channel_header.tx_id" block1.txt)
echo "Transaction(s)($TRX_COUNT)  $TX_ID is on the block $i" 
echo "Transaction(s)($TRX_COUNT)  $TX_ID is on the block $i" >&log.txt
done
echo
echo "TOTAL transaction on channel mychannel0 on peer2 is $TOTAL_TRX"
printf "\n\nTotal execution time : $(($(date +%s)-starttime)) secs ...\n\n"
