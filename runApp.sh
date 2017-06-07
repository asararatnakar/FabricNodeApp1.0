#!/bin/bash

START_STOP="$1"

: ${START_STOP:="restart"}

function dkcl(){
        CONTAINERS=$(docker ps -a|wc -l)
        if [ "$CONTAINERS" -gt "1" ]; then
                docker rm -f $(docker ps -aq)
        else
                echo "========== No containers available for deletion =========="
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
function installNodeModules() {
        echo
        if [ -d node_modules ]; then
                echo "============== node modules installed already ============="
        else
                echo "============== Installing node modules ============="
                npm install
        fi
        echo
}

function startApp() {
	#Start the network
	docker-compose -f ./artifacts/docker-compose.yaml up -d
	echo

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
