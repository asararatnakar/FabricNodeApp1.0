var figlet = require('figlet');
const util = require('util')

const invokeQueryFcnName = "invoke";

var printJSON = function (message) {
	//TODO: comeup with a better format for the output
	console.log('\n**********************************************************');
	console.log( util.inspect(message, {depth: null, colors: true}));
	console.log('**********************************************************\n\n');
}

var banner = function(title) {
	figlet(title, function(err, data) {
    	if (err) {
        	console.log('Something went wrong...');
        	console.dir(err);
        	return;
    	}
	    console.log(data)
	});
}
exports.printJSON = printJSON;
exports.banner = banner;
