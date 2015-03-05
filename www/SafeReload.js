var argscheck = require('cordova/argscheck'),
    exec = require('cordova/exec');

/**
 * SafeReload checks to make sure that JS & CSS are working inside the WebView after a Meteor HCP.
 * @constructor
 */
var SafeReload = {

    healthCheckPassed: function() {
        exec(null, null, "SafeReload", "bridgeHealthCheckPassed", []);
    },

    healthCheckFailed: function() {
        exec(null, null, "SafeReload", "bridgeHealthCheckFailed", []);
    }
};

module.exports = SafeReload;
