/**
 * Copyright 2017 IBM All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
'use strict';
var path = require('path');
var fs = require('fs');
var util = require('util');
var hfc = require('fabric-client');
var Peer = require('fabric-client/lib/Peer.js');
var config = require('../config.json');
var helper = require('./helper.js');
var logger = helper.getLogger('invoke-chaincode');
var EventHub = require('fabric-client/lib/EventHub.js');
hfc.addConfigFile(path.join(__dirname, 'network-config.json'));
var ORGS = hfc.getConfigSetting('network-config');
var ordererFailure = 0;
var peerFailures = 0;
var allEventhubs = [];
var propResponse = null;
var tempPropResponse = null;
var deferred = Promise.defer();
var propRequest = {};
var invokeChaincode = function(peersUrls, channelName, chaincodeName, fcn, args, username, org) {
    logger.debug(util.format('\n============ invoke transaction on organization %s ============\n', org));
    var client = helper.getClientForOrg(org);
    var channel = helper.getChannelForOrg(org, channelName);
    if (peerFailures > 0) {
        //TODO: Add your peers here
        peersUrls = []; // rather eiminate duplicates
        peersUrls.push('localhost:8051');
    }
    var targets = helper.newPeers(peersUrls);
    var tx_id = null;
    var ordererCount = channel.getOrderers().length;
    var closeConnections = function() {
        for (var key in allEventhubs) {
            var eventhub = allEventhubs[key];
            if (eventhub && eventhub.isconnected()) {
                logger.debug('Disconnecting the event hub');
                eventhub.disconnect();
            }
        }
    };
    return helper.getRegisteredUsers(username, org).then((user) => {
        if (ordererFailure > 0 && propResponse) {
            return propResponse;
        } else {
            tx_id = client.newTransactionID();
            logger.debug(util.format('Sending transaction "%j"', tx_id));
            // send proposal to endorser
            propRequest = {
                targets: targets,
                chaincodeId: chaincodeName,
                fcn: fcn,
                args: args,
                chainId: channelName,
                txId: tx_id
            };
            return channel.sendTransactionProposal(propRequest);
        }
    }, (err) => {
        logger.error('Failed to enroll user \'' + username + '\'. ' + err);
        throw new Error('Failed to enroll user \'' + username + '\'. ' + err);
    }).then((results) => {

        var proposalResponses = results[0];
        var proposal = results[1];
        var header = results[2];
        if (ordererFailure > 0) {
            //TODO: why the offset values are getting changed ?
            proposal.payload.offset = 0;
            proposal.header.offset = 0;
        }
        var all_good = true;
        for (var i in proposalResponses) {
            let one_good = false;
            if (proposalResponses && proposalResponses[0].response &&
                proposalResponses[0].response.status === 200) {
                one_good = true;
                logger.info('transaction proposal was good');
            } else {
                logger.error('transaction proposal was bad');
            }
            all_good = all_good & one_good;
        }
        if (!all_good && peerFailures < ordererCount) {
            peerFailures++;
            logger.debug('\n>>>>>>>>>>>>>>>  R E T R Y  - ' + peerFailures + '  <<<<<<<<<<<<\n');
            invokeChaincode(peersUrls, channelName, chaincodeName, fcn, args, username, org);
        }
        if (all_good) {
            if (ordererFailure < 1) {
                tempPropResponse = results;
            }
            propResponse = results;
            logger.debug(util.format(
                'Successfully sent Proposal and received ProposalResponse: Status - %s, message - "%s", metadata - "%s", endorsement signature: %s',
                proposalResponses[0].response.status, proposalResponses[0].response.message,
                proposalResponses[0].response.payload, proposalResponses[0].endorsement
                .signature));
            var request = {
                proposalResponses: proposalResponses,
                proposal: proposal,
                header: header
            };
            // set the transaction listener and set a timeout of 30sec
            // if the transaction did not get committed within the timeout period,
            // fail the test
            var transactionID = propRequest.txId.getTransactionID();
            var sendPromise = channel.sendTransaction(request);

            var eventPromises = [];

            var eventhubs = helper.newEventHubs(peersUrls, org);
            for (let key in eventhubs) {
                let eh = eventhubs[key];
                eh.connect();
                allEventhubs.push(eh);

                let txPromise = new Promise((resolve, reject) => {
                    let handle = setTimeout(() => {
                        eh.disconnect();
                        reject();
                    }, 30000);

                    eh.registerTxEvent(transactionID, (tx, code) => {
                        clearTimeout(handle);
                        eh.unregisterTxEvent(transactionID);
                        eh.disconnect();

                        if (code !== 'VALID') {
                            logger.error(
                                'The balance transfer transaction was invalid, code = ' + code);
                            reject();
                        } else {
                            logger.info(
                                'The balance transfer transaction has been committed on peer ' +
                                eh._ep._endpoint.addr);
                            resolve();
                        }
                    });
                });
                eventPromises.push(txPromise);
            };

            return Promise.all([sendPromise].concat(eventPromises)).then((results) => {
                logger.debug(' event promise all complete and testing complete');
                return results[0]; // the first returned value is from the 'sendPromise' which is from the 'sendTransaction()' call
            }).catch((err) => {
                closeConnections();
                //Check if this error is from Ordering Service
                if (err && err.stack.toString().indexOf('SERVICE_UNAVAILABLE') > -1) {
                    //return 'Failed to send transaction and get notifications within the timeout period.';
                    return 'SERVICE_UNAVAILABLE';
                }
                return 'Failed to send transaction and get notifications within the timeout period.';
            });
        } else {
            logger.error(
                'Failed to send Proposal or receive valid response. Response null or status is not 200. exiting...'
            );
            return 'Failed to send Proposal or receive valid response. Response null or status is not 200. exiting...';
        }
    }, (err) => {
        logger.error('Failed to send proposal due to error: ' + err.stack ? err.stack :
            err);
        return 'Failed to send proposal due to error: ' + err.stack ? err.stack :
            err;
    }).then((response) => {
        if (response.status === 'SUCCESS') {
            ordererFailure = 0;
            propResponse = null;
            logger.info('Successfully sent transaction to the orderer.');
            return propRequest.txId.getTransactionID();
            //tx_id.getTransactionID();
        } else {
            if (response && response.indexOf('SERVICE_UNAVAILABLE') > -1 && ordererFailure < ordererCount) {
                let orderers = channel.getOrderers();
                let ordererToRemove = orderers[0];
                logger.debug(orderers[1]);
                channel.removeOrderer(ordererToRemove);
                channel.addOrderer(ordererToRemove);
                ordererFailure++;
                logger.debug('\n>>>>>>>>>>>>>>>  R E T R Y  - ' + ordererFailure + '  <<<<<<<<<<<<\n');
                invokeChaincode(peersUrls, channelName, chaincodeName, fcn, args, username, org);
                //return 'Failed to send transaction and get notifications within the timeout period.';
                if (ordererFailure === ordererCount) {
                    ordererFailure = 0; // TODO: Is this rt ?
                    return 'SERVICE_UNAVAILABLE';
                }
            } else {
                logger.error('Failed to order the transaction. Error code: ' + response);
                return 'Failed to order the transaction. Error code: ' + response;
            }
        }
    }, (err) => {
        logger.error('Failed to send transaction due to error: ' + err.stack ? err
            .stack : err);
        return 'Failed to send transaction due to error: ' + err.stack ? err.stack :
            err;
    });
};

exports.invokeChaincode = invokeChaincode;