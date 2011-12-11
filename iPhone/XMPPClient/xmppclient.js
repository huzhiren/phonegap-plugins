/**
 * Phonegap XMPP client plugin
 * Copyright (c) Ryan 2011
 *
 */

var XMPPClient = function() { 
    
};

XMPPClient.prototype = {
    
    /**
	 * window.plugins.xmppclient.login(
	 *	'test.com', 
	 *	5222, 
	 *	'test@test.com',
	 *	'123456', 
	 *	function(status) {
	 *		alert('login success');
	 *	},
	 *	function(error) {
	 *		alert(error);
	 *	}
	 * );
	 */
    login : function(host, port, jid, pass, success, fail) {   
        return PhoneGap.exec(success, fail, "com.phonegap.xmppclient", "login", [host, port, jid, pass]);
    },
    
    /**
     * window.plugins.xmppclient.send(
     * 	'test message',
     * 	'test@test.com',
     * 	function(status) {
     * 		alert('sending success');
     * 	},
     * 	function(error) {
     * 		alert(error);
     * 	}
     * );
     */
    send : function(message, to, success, fail) {
        return PhoneGap.exec(success, fail, "com.phonegap.xmppclient", "send", [message, to]);
    },
    
    /**
     * window.plugins.xmppclient.onMessage(function(message) {
     * 		alert(message.from+' : '+message.body);
     * });
     */
    onMessage : function(onMessageCallback) {
        return PhoneGap.exec(onMessageCallback, null, "com.phonegap.xmppclient", "onMessage", []);
    },
    
    /**
     * window.plugins.xmppclient.logout();
     */
    logout : function() {
        return PhoneGap.exec(null, null, "com.phonegap.xmppclient", "logout", []);
    },
    
    /**
     * window.plugins.xmppclient.isConnected(
     * 	function() {
     * 		// connected
     * 	},
     * 	function() {
     * 		// disconnect
     * 	}
     * );
     */
    isConnected : function(connected, disconnected) {
        return PhoneGap.exec(connected, disconnected, "com.phonegap.xmppclient", "isConnected", []);
    }
    
};

PhoneGap.addConstructor(function()  {
    if(!window.plugins) {
        window.plugins = {};
    }
    window.plugins.xmppclient = new XMPPClient();
});
