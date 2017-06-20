/**
 * Copyright 2017 IBM All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an 'AS IS' BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
var util = require('util');
var fs = require('fs');
var path = require('path');
var config = require('../config.json');
var helper = require('./helper.js');
var logger = helper.getLogger('Create-Channel');
//Attempt to send a request to the orderer with the sendCreateChain method
var createChannel = function(channelName, channelConfigPath, configUpdate, username, orgName) {
	logger.debug('\n====== Creating Channel \'' + channelName + '\' ======\n');
	var client = helper.getClientForOrg(orgName);
	var channel = helper.getChannelForOrg(orgName, channelName);
	// read in the envelope for the channel config raw bytes
	var envelope = fs.readFileSync(path.join(__dirname, channelConfigPath));
	// extract the channel config bytes from the envelope to be signed
	var channelConfig = client.extractChannelConfig(envelope);
        var signatures = [];
	//Acting as a client in the given organization provided with "orgName" param
	return helper.getOrgAdmin(orgName).then((admin) => {
		logger.debug(util.format('Successfully acquired admin user for the organization "%s"', orgName));
		// sign the channel config bytes as "endorsement", this is required by
		// the orderer's channel creation policy
		let signature = client.signChannelConfig(channelConfig);
		signatures.push(signature)
		// If it is a config update then sign with second organization
		if (configUpdate){
			//FIXME: change the logic to get the rest of the orgs clients
			var otherOrg;
			if (orgName == 'org1') {
				otherOrg = 'org2';
			} else {
				otherOrg = 'org1';
			}
			var otherClient = helper.getClientForOrg(otherOrg);
			signature = otherClient.signChannelConfig(channelConfig);
			signatures.push(signature)
		}

		let request = {
			config: channelConfig,
			signatures: signatures,
			name: channelName,
			orderer: channel.getOrderers()[0],
			txId: client.newTransactionID()
		};

		// send to orderer
		if (configUpdate){
			return client.createChannel(request);
		} else {
			return client.updateChannel(request);
		}

	}, (err) => {
		logger.error('Failed to enroll user \''+username+'\'. Error: ' + err);
		throw new Error('Failed to enroll user \''+username+'\'' + err);
	}).then((response) => {
		logger.debug(' response ::%j', response);
		if (response && response.status === 'SUCCESS') {

			let response = {
				success: true,
			};
			if (configUpdate) {
				logger.debug('Successfully updated the channel.');
				response.message = 'Channel \'' + channelName + '\' updated Successfully'
			} else {
				logger.debug('Successfully created the channel.');
				response.message = 'Channel \'' + channelName + '\' created Successfully'
			}
		  return response;
		} else {
			if (configUpdate) {
				logger.error('\n!!!!!!!!! Failed to update the channel \'' + channelName +
					'\' !!!!!!!!!\n\n');
				throw new Error('Failed to update the channel \'' + channelName + '\'');

			} else {
				logger.error('\n!!!!!!!!! Failed to create the channel \'' + channelName +
					'\' !!!!!!!!!\n\n');
				throw new Error('Failed to create the channel \'' + channelName + '\'');
			}
		}
	}, (err) => {
		logger.error('Failed to initialize the channel: ' + err.stack ? err.stack :
			err);
		throw new Error('Failed to initialize the channel: ' + err.stack ? err.stack : err);
	});
};

exports.createChannel = createChannel;
