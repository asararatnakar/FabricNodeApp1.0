#!/bin/bash +x
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


#set -e

CHANNEL_NAME=$1
TOTAL_CHANNELS=$2
: ${CHANNEL_NAME:="mychannel"}
: ${TOTAL_CHANNELS:="2"}
echo "Using CHANNEL_NAME prefix as $CHANNEL_NAME"
CURRENT_DIR=$PWD
export FABRIC_CFG_PATH=$PWD/artifacts/config

#OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

function generateCerts (){
	CRYPTOGEN=$PWD/bin/cryptogen
	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"
	$CRYPTOGEN generate --config=./config/cryptogen.yaml
	echo
}

## docker-compose template to replace private key file names with constants
function replacePrivateKey () {
	ARCH=`uname -s | grep Darwin`
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	cp docker-compose-template.yaml docker-compose.yaml

  cd crypto-config/peerOrganizations/org1.example.com/ca/
  PRIV_KEY=$(ls *_sk)
  cd $CURRENT_DIR/artifacts
  sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
  cd crypto-config/peerOrganizations/org2.example.com/ca/
  PRIV_KEY=$(ls *_sk)
  cd $CURRENT_DIR/artifacts
  sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {

	CONFIGTXGEN=$PWD/bin/configtxgen

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./channel/genesis.block

	for (( i=1; i<=$TOTAL_CHANNELS; i=$i+1 ))
	do
		echo
		echo "#################################################################"
		echo "### Generating channel configuration transaction '$CHANNEL_NAME$i.tx' ###"
		echo "#################################################################"
		$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./channel/$CHANNEL_NAME$i.tx -channelID $CHANNEL_NAME$i
		echo
	done
}

cd artifacts
generateCerts
replacePrivateKey
generateChannelArtifacts
cd $CURRENT_DIR
