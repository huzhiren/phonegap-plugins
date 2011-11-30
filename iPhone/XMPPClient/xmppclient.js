/**
 * Phonegap XMPP client plugin
 * Copyright (c) Ryan 2011
 *
 */

var XMPPClient = { };

XMPPClient.prototype = {
    
    login : function(host, port, jid, pass, success, fail) {   
        return PhoneGap.exec("XMPPClient.login", host, port, jid, pass, GetFunctionName(success), GetFunctionName(fail));
    },
    
    send : function(to, message, success, fail) {
        return PhoneGap.exec("XMPPClient.send", message, to, GetFunctionName(success), GetFunctionName(fail));
    },
    
    onMessage : function(onMessageCallback) {
        return PhoneGap.exec("XMPPClient.onMessage", GetFunctionName(onMessageCallback));
    },
    
    logout : function() {
        return PhoneGap.exec("XMPPClient.logout");
    },
    
    isConnected : function(connected, disconnected) {
        return PhoneGap.exec("XMPPClient.isConnected", GetFunctionName(connected), GetFunctionName(disconnected));
    }
};


PhoneGap.addConstructor(function()  {
    if(!window.plugins) {
        window.plugins = {};
    }
    window.plugins.xmppclient = new XMPPClient();
});
