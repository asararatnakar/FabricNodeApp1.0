/*
curl -s -X POST \
  http://localhost:4000/users \
  -H "content-type: application/x-www-form-urlencoded" \
  -d 'username=Jim&orgName=org1'
*/
var config = require('./testconfig.json');
var request = require('request');
var testUtils = require('./testUtils.js');

var host = process.env.HOST || config.host;
var port = process.env.POST || config.port;
var title = process.env.banner || config.banner;

var URL = 'http://'+host+':'+port;

// Print banner
testUtils.banner(title);

var org1Token;


// User registartion test
for (let i=config.orgs.length-1;i>=0;i -- ) {
request.post({url:URL+'/users', form: {'username':config.users[i], 'orgName':config.orgs[i].orgName}}, function(error,response,body) { 
	if (!error && response.statusCode == 200) {
		var json = JSON.parse(body);
		testUtils.printJSON(json);
		org1Token = json.token;
		console.log(config.orgs[i].orgName+" Token : "+ org1Token);
     	} else {
		process.exit();
	}
})
}
