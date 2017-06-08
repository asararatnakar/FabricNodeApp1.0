#!/bin/bash

START_STOP="$1"
TAG="$2"

: ${START_STOP:="restart"}
: ${TAG:="beta"}
ARCH=`uname -m`
export IMAGE_TAG="`uname -m`-1.0.0-$TAG"
printf "\n ========= IMAGE TAG : $IMAGE_TAG ===========\n"
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
	DOCKER_IMAGES=$(docker images | grep "$IMAGE_TAG" | wc -l)
	if [ $DOCKER_IMAGES -ne 9 ]; then
		printf "\n############# You don't have all the images, Let me them pull for you ###########\n"
		for IMAGE in ca peer orderer couchdb ccenv javaenv kafka tools zookeeper; do
		      docker pull hyperledger/fabric-$IMAGE:$IMAGE_TAG
		done
	fi
}

function startApp() {
	checkForDockerImages
	#Start the network
	docker-compose -f ./artifacts/docker-compose.yaml up -d
	if [ $? -ne 0 ]; then
		printf "\n\n!!!!!!!! Unable to pull the start the network, Check your docker-compose !!!!!\n\n"
		exit
	fi

	##Install node modules
        installNodeModules

	##Start app on port 4000
	PORT=4000 node app
}

function shutdownApp() {
	echo

        #teardown the network and clean the containers and intermediate images
	docker-compose -f ./artifacts/docker-compose.yaml down
	dkcl
	dkrm

	#Cleanup the material
	rm -rf /tmp/hfc-test-kvs_peerOrg* $HOME/.hfc-key-store/ /tmp/fabric-client-kvs_peerOrg*
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
