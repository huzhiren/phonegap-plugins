# XMPP Client plugin for Phonegap #
By Ryan Hubert

## Adding the Plugin to your project ##
Copy the .h and .mm file to the Plugins directory in your project. Copy the .js file to your www directory and reference it from your html file(s). Remember to add xmppClient->XMPPClient plugin definition in PhoneGap.plist. You also need to add the XMPPFramework to your project.

## Adding XMPPFramework to your project ##
First, [Create a clone of the xmppframework repository](http://code.google.com/p/xmppframework/source/checkout), the follow the instructions in the Wiki page(http://code.google.com/p/xmppframework/wiki/GettingStarted_iOS). 

## Example of Using the plugin ##
    var to = 'outrousuario@jabber.org';

onMessage = function(from, message) {
	alert(from+" : "+message);
}
    
           
connect = function() {
	window.plugins.xmppclient.login(
        	"jabber.org", 
                 5222,
                 "usuario@jabber.org",
                 "senha",
                 function() {
		     window.plugins.xmppclient.onMessage(onMessage);
                     window.plugins.xmppclient.send("Hi there!", to);
                 },
                 function(status) {
                     alert("connect failed: " + status);
                 }
        );
}

document.addEventListener("deviceready", connect, true);

## BUGS AND CONTRIBUTIONS ##
The latest bleeding-edge version is available [on GitHub](http://github.com/ascorbic/phonegap-plugins/tree/master/iPhone/)
If you have a patch, fork my repo and send me a pull request. Submit bug reports on GitHub, please.
	
## Licence ##

The MIT License

Copyright (c) 2011 Matt Kane

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

