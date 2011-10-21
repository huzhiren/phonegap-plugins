//
//  XMPPClient.mm
//
//  Created by Ryan on 14/10/2011.
//  Copyright 2011 Ryan Hubert. All rights reserved.
//

#import "XMPPClient.h"

#import "GCDAsyncSocket.h"
#import "XMPP.h"
#import "XMPPReconnect.h"

#import "DDLog.h"
#import "DDTTYLogger.h"

#import <CFNetwork/CFNetwork.h>


@implementation XMPPClient

@synthesize successCallback;
@synthesize failCallback;
@synthesize password;
@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize allowSelfSignedCertificates;
@synthesize allowSSLHostNameMismatch;
@synthesize isXmppConnected;

- (id) init {
    self = [super init];
    if(self) {
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        NSLog(@"XMPPClient init");
        isXmppConnected = NO;
    }
    return self;
}

// It's easy to create XML elments to send and to read received XML elements.
// You have the entire NSXMLElement and NSXMLNode API's.
// 
// In addition to this, the NSXMLElement+XMPP category provides some very handy methods for working with XMPP.
// 
// On the iPhone, Apple chose not to include the full NSXML suite.
// No problem - we use the KissXML library as a drop in replacement.
// 
// For more information on working with XML elements, see the Wiki article:
// http://code.google.com/p/xmppframework/wiki/WorkingWithElements

- (void)goOnline {
	XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
	[[self xmppStream] sendElement:presence];
}

- (void)goOffline {
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
	[[self xmppStream] sendElement:presence];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket {
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings {	
	if (allowSelfSignedCertificates) {
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	if (allowSSLHostNameMismatch) {
		[settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
	}
	else {
		// Google does things incorrectly (does not conform to RFC).
		// Because so many people ask questions about this (assume xmpp framework is broken),
		// I've explicitly added code that shows how other xmpp clients "do the right thing"
		// when connecting to a google server (gmail, or google apps for domains).
		
		NSString *expectedCertName = nil;
		
		NSString *serverDomain = xmppStream.hostName;
		NSString *virtualDomain = [xmppStream.myJID domain];
		
		if ([serverDomain isEqualToString:@"talk.google.com"]) {
			if ([virtualDomain isEqualToString:@"gmail.com"]) {
				expectedCertName = virtualDomain;
			}
			else {
				expectedCertName = serverDomain;
			}
		}
		else if (serverDomain == nil) {
			expectedCertName = virtualDomain;
		}
		else {
			expectedCertName = serverDomain;
		}
		
		if(expectedCertName) {
			[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
		}
	}
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender {
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender {	
	isXmppConnected = YES;
	
	NSError *error = nil;
	
	if(![[self xmppStream] authenticateWithPassword:password error:&error]) {
		NSLog(@"Error authenticating: %@", error);
        NSString* jsCallBack = [NSString stringWithFormat:@"%@(\"Error authenticating: %@\");", failCallback, error];
        [self writeJavascript: jsCallBack];
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
	NSString* jsCallBack = [NSString stringWithFormat:@"%@();", successCallback];
    [self writeJavascript: jsCallBack];
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error {
    NSString* jsCallBack = [NSString stringWithFormat:@"%@(\"Error authenticating: %@\");", failCallback, error];
    [self writeJavascript: jsCallBack];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSLog(@"%@", [iq elementID]);
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {    
	// A simple example of inbound message handling.
    
	if ([message isChatMessageWithBody]) {
		
        if(onMessageCallback!=nil) {
            XMPPJID* from = [message from];
            NSString* jid = [from bare]; 
            NSString* body = [[message elementForName:@"body"] stringValue];
            NSLog(@"Received from %@: %@", jid, body);
            
            NSString* jsCallBack = [NSString stringWithFormat:@"%@(\"%@\",\"%@\");", onMessageCallback, jid, body];
            [self writeJavascript: jsCallBack];            
        }
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {
	NSLog(@"%@", [presence fromStr]);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error {
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {	
	if (!isXmppConnected) {
		NSLog(@"Unable to connect to server. Check xmppStream.hostName");
	}
}


- (void) login:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSUInteger argc = [arguments count];
	
	if (argc < 6) {
        NSLog(@"The arguments passed to login() must be (host, port, jid, password, successCallback, failCallback)");
		return;	
	}

    NSString *host = [[arguments objectAtIndex:0] copy];
    UInt16 port = [[arguments objectAtIndex:1] intValue];
    NSString *jid = [[arguments objectAtIndex:2] copy];
    password = [[arguments objectAtIndex:3] copy];
    successCallback = [[arguments objectAtIndex:4] copy];
	failCallback = [[arguments objectAtIndex:5] copy];
	
   	if (xmppStream!=nil && ![xmppStream isDisconnected]) {
		return;
	}
	
	// Setup xmpp stream
	// 
	// The XMPPStream is the base class for all activity.
	// Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
	xmppStream = [[XMPPStream alloc] init];
	
#if !TARGET_IPHONE_SIMULATOR
	{
		// Want xmpp to run in the background?
		// 
		// P.S. - The simulator doesn't support backgrounding yet.
		//        When you try to set the associated property on the simulator, it simply fails.
		//        And when you background an app on the simulator,
		//        it just queues network traffic til the app is foregrounded again.
		//        We are patiently waiting for a fix from Apple.
		//        If you do enableBackgroundingOnSocket on the simulator,
		//        you will simply see an error message from the xmpp stack when it fails to set the property.
		
		xmppStream.enableBackgroundingOnSocket = YES;
	}
#endif
	// Setup reconnect
	// 
	// The XMPPReconnect module monitors for "accidental disconnections" and
	// automatically reconnects the stream for you.
	// There's a bunch more information in the XMPPReconnect header file.
	
	xmppReconnect = [[XMPPReconnect alloc] init];
	
    
	// Activate xmpp modules
    
	[xmppReconnect         activate:xmppStream];
    
	// Add ourself as a delegate to anything we may be interested in
    
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
	// 
	// Replace me with the proper domain and port.
	// The example below is setup for a typical google talk account.
	// 
	// If you don't supply a hostName, then it will be automatically resolved using the JID (below).
	// For example, if you supply a JID like 'user@quack.com/rsrc'
	// then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
	// 
	// If you don't specify a hostPort, then the default (5222) will be used.
	
    [xmppStream setHostName:host];
    [xmppStream setHostPort:port]; 
    
    // You may need to alter these settings depending on the server you're connecting to
	allowSelfSignedCertificates = YES;
	allowSSLHostNameMismatch = YES;

    
	[xmppStream setMyJID:[XMPPJID jidWithString:jid]];

	NSError *error = nil;
	if (![xmppStream connect:&error]) {
		NSLog(@"Error connecting: %@", error);
        NSString* jsCallBack = [NSString stringWithFormat:@"%@(\"Error connecting: %@\");", failCallback, error];
        [self writeJavascript: jsCallBack];
	}
    
    [host release];
    [jid release];
}

- (void) logout:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    [self goOffline];
    
    [xmppStream disconnect];
    
    [xmppStream removeDelegate:self];
	
	[xmppReconnect deactivate];
	
	[xmppStream disconnect];
	
	[xmppStream release];
	[xmppReconnect release];
    [successCallback release];
    [failCallback release];
    [password release];
    [onMessageCallback release];
    
	xmppStream = nil;
	xmppReconnect = nil;
    successCallback = nil;
    failCallback = nil;
    password = nil;
    onMessageCallback = nil;
    isXmppConnected = NO;
}

- (void) send:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSUInteger argc = [arguments count];
	
	if (argc < 2) {
		return;	
	}
    NSString* message = [[arguments objectAtIndex:0] copy];
    NSString* to = [[arguments objectAtIndex:1] copy];
    
    NSXMLElement* body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:message];
    
    NSXMLElement* messageElement = [NSXMLElement elementWithName:@"message"];
    [messageElement addAttributeWithName:@"type" stringValue:@"chat"];
    [messageElement addAttributeWithName:@"to" stringValue:to];
    [messageElement addChild:body];
    
    [xmppStream sendElement:messageElement];
    
    [message release];
    [to release];
}

- (void) onMessage:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSUInteger argc = [arguments count];
	
	if (argc < 1) {
		return;	
	}
    onMessageCallback = [[arguments objectAtIndex:0] copy];
}

- (void) isConnected:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSString* connect = [[arguments objectAtIndex:0] copy];
    NSString* disconnect = [[arguments objectAtIndex:1] copy];
    NSString* jsCallBack = [NSString stringWithFormat:@"%@();", isXmppConnected? connect:disconnect];
    [self writeJavascript: jsCallBack];
    [connect release];
    [disconnect release];    
}

@end
