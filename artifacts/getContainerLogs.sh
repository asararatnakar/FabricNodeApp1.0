#!/bin/bash

function getLogs(){
	## If no containers running return
	CONTAINERS=$(docker ps -a | wc -l)
        if test $CONTAINERS -eq 1
	then
		echo "============= No Docker Containers running =========="
		return
	fi

	printf "=========================================================\n"
	printf "        START CAPTURE ALL DOCKER CONTAINER LOGS \n"
	printf "=========================================================\n"

        DATE=`date +%Y_%m_%d_%H_%M_%S`
        TAR_FILE="$DATE-logs.tar.gz"

	for (( i=0; i<3; i=$i+1))
	do
		docker logs zookeeper$i >& zookeeper$i.txt
		docker logs kafka$i >& kafka$i.txt
		docker logs orderer$i.example.com >& orderer$i.txt
		#docker logs couchdb$i &> couchdb$i.txt
	done
	#docker logs couchdb3 &> couchdb3.txt
	docker logs peer0.org1.example.com &> peer0_org1.txt
	docker logs peer1.org1.example.com &> peer1_org1.txt
	docker logs peer0.org2.example.com &> peer0_org2.txt
	docker logs peer1.org2.example.com &> peer1_org2.txt

	if [ ! -d logs ]; then
		mkdir logs
	fi

	## tar the logs
	tar czf logs/$TAR_FILE *.txt

	## cleanup
	rm -rf *.txt

	printf "=========================================================\n"
	printf "      CAPTURED DOCKER CONTAINER LOGS TO $TAR_FILE \n"
	printf "=========================================================\n"
}
getLogs
