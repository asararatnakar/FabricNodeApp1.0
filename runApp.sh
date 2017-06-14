#!/bin/bash

START_STOP="$1"
TAG="$2"

: ${START_STOP:="restart"}
: ${TAG:="beta"}
ARCH=`uname -m`
#export IMAGE_TAG="`uname -m`-1.0.0-$TAG"
export FABRIC_IMAGE_TAG="x86_64-1.0.0-rc1-snapshot-123b3d7"
export FABRIC_CA_IMAGE_TAG="x86_64-1.0.0-rc1-snapshot-1424b33"
function dkcl(){
        CONTAINERS=$(docker ps -a|wc -l)
        if [ "$CONTAINERS" -gt "1" ]; then
                docker rm -f $(docker ps -aq)
        else
                printf "\n========== No containers available for deletion ==========\n"
        fi
}

function dkrm(){
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
	echo
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
		echo "========== No images available for deletion ==========="
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
	echo
}

function cleanAndInstall() {
	## Make sure cleanup the node_moudles and re-install them again
	rm -rf ./node_modules

	printf "\n============== Installing node modules =============\n"
	npm install
}

function installNodeModules() {
        echo
        if [ -d node_modules ]; then
		npm ls fabric-client && npm ls fabric-ca-client || cleanAndInstall
        else
                cleanAndInstall
        fi
        echo
}
function checkForDockerImages() {
	DOCKER_IMAGES=$(docker images | grep "$FABRIC_IMAGE_TAG" | wc -l)
	if [ $DOCKER_IMAGES -ne 8 ]; then
		printf "\n############# You don't have all fabric images, Let me them pull for you ###########\n"
		for IMAGE in peer orderer couchdb ccenv javaenv kafka tools zookeeper; do
		      docker pull hyperledger/fabric-$IMAGE:$FABRIC_IMAGE_TAG
		done
	fi
  DOCKER_IMAGES=$(docker images | grep "$FABRIC_CA_IMAGE_TAG" | wc -l)
  if [ $DOCKER_IMAGES -ne 1 ]; then
    printf "\n############# You don't have fabric ca images, Let me them pull for you ###########\n"
    docker pull hyperledger/fabric-ca:$FABRIC_CA_IMAGE_TAG
  fi
}

function startApp() {
  printf "\n ========= FABRIC IMAGE TAG : $FABRIC_IMAGE_TAG ===========\n"
  printf "\n ========= FABRIC-CA IMAGE TAG : $FABRIC_CA_IMAGE_TAG ===========\n"

  #if [ "$TAG" = "beta" ]; then
	#checkForDockerImages
  #fi

  #source artifacts/generateArtifacts.sh
	#Start the network
	docker-compose -f ./artifacts/docker-compose.yaml -f ./artifacts/docker-compose-couch.yaml up -d
	if [ $? -ne 0 ]; then
		printf "\n\n!!!!!!!! Unable to pull the start the network, Check your docker-compose !!!!!\n\n"
		exit
	fi
  #exit
	##Install node modules
  installNodeModules

	##Start app on port 4000
	PORT=4000 node app
}

function shutdownApp() {
	printf "\n======================= TEARDOWN NETWORK ====================\n"
	# teardown the network and clean the containers and intermediate images
	docker-compose -f ./artifacts/docker-compose.yaml -f ./artifacts/docker-compose-couch.yaml down
	dkcl
	dkrm

	# cleanup the material
	printf "\n======================= CLEANINGUP ARTIFACTS ====================\n\n"
	rm -rf /tmp/hfc-test-kvs_peerOrg* $HOME/.hfc-key-store/ /tmp/fabric-client-kvs_peerOrg*
	#rm -rf ./artifacts/channel/*.block channel/*.tx ./artifacts/crypto-config
}

#Create the network using docker compose
if [ "${START_STOP}" == "start" ]; then
        startApp
elif [ "${START_STOP}" == "stop" ]; then ## Clear the network
        shutdownApp
elif [ "${START_STOP}" == "restart" ]; then ## Restart the network
        shutdownApp
        startApp
else
        echo "Usage: ./runApp.sh [start|stop|restart]"
        exit 1
fi
