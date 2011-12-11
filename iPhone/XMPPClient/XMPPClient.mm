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

@synthesize xmppStream;
@synthesize xmppReconnect;
@synthesize allowSelfSignedCertificates;
@synthesize allowSSLHostNameMismatch;
@synthesize isXmppConnected;

- (PGPlugin*) initWithWebView:(UIWebView*)theWebView settings:(NSDictionary*)classSettings {
    [self init];
    return [super initWithWebView: theWebView];
}

- (PGPlugin*) initWithWebView:(UIWebView*)theWebView {
    [self init];
    return [super initWithWebView: theWebView];
}

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
    
    NSString* password = [cache valueForKey:@"password"];
    NSString* callbackId = [cache valueForKey:@"callbackId"];
	
	if(![[self xmppStream] authenticateWithPassword:password error:&error]) {
		NSLog(@"Error authenticating: %@", error);
        PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_ERROR messageAsString: [error description]];
        NSString* js = [result toErrorCallbackString:callbackId];
        [self writeJavascript:js];
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    NSString* callbackId = [cache valueForKey:@"callbackId"];
    PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK];
    NSString* js = [result toSuccessCallbackString:callbackId];
    [self writeJavascript:js];
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error {
    NSString* callbackId = [cache valueForKey:@"callbackId"];
    PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_ERROR messageAsString: [error description]];
    NSString* js = [result toErrorCallbackString:callbackId];
    [self writeJavascript:js];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	NSLog(@"%@", [iq elementID]);
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {    
	// A simple example of inbound message handling.
    
	if ([message isChatMessageWithBody]) {
		NSString* callbackId = [cache valueForKey:@"onMessage"];

        if(callbackId!=nil) {
            XMPPJID* from = [message from];
            NSString* jid = [from bare]; 
            NSString* body = [[message elementForName:@"body"] stringValue];
            NSLog(@"Received from %@: %@", jid, body);
            NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  jid, @"from",
                                  body, @"body",
                                  nil];
            PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK messageAsDictionary: dict];
            [result setKeepCallbackAsBool:YES];
            NSString* js = [result toSuccessCallbackString: callbackId];
            [self writeJavascript:js];
        }
	}
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
    NSString* callbackId = [cache valueForKey:@"onSent"];
    if(callbackId) {
        PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_OK];
        NSString* js = [result toSuccessCallbackString:callbackId];
        [self writeJavascript:js];
        [cache removeObjectForKey:@"onSent"];
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
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString* host = [arguments objectAtIndex:1];
    UInt16 port = [[arguments objectAtIndex:2] intValue];
    NSString* jid = [arguments objectAtIndex:3];
    NSString* password = [arguments objectAtIndex:4];
	
   	if (xmppStream!=nil && ![xmppStream isDisconnected]) {
		return;
	}
	    
	xmppStream = [[XMPPStream alloc] init];
    cache = [[NSMutableDictionary alloc] init];
	
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
	
	xmppReconnect = [[XMPPReconnect alloc] init];
    
	[xmppReconnect activate:xmppStream];
    
	[xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
    [xmppStream setHostName:host];
    [xmppStream setHostPort:port]; 
    
    // You may need to alter these settings depending on the server you're connecting to
	allowSelfSignedCertificates = YES;
	allowSSLHostNameMismatch = YES;
    
	[xmppStream setMyJID:[XMPPJID jidWithString:jid]];
    [cache setValue:callbackId forKey:@"callbackId"];
    [cache setValue:password forKey:@"password"];
    
    
	NSError *error = nil;
	if (![xmppStream connect:&error]) {
		NSLog(@"Error connecting: %@", error);
        
        PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_ERROR messageAsString: [error description]];
        NSString* js = [result toErrorCallbackString:callbackId];
        [self writeJavascript:js];
	}
}

- (void) logout:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    [self goOffline];
    
    [xmppStream disconnect];
    
    [xmppStream removeDelegate:self];
	
	[xmppReconnect deactivate];
	
	[xmppStream disconnect];
	
	[xmppStream release];
	[xmppReconnect release];
    
    [cache release];
 
	xmppStream = nil;
	xmppReconnect = nil;
    isXmppConnected = NO;
    cache = nil;
}

- (void) send:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSString* callbackId = [arguments objectAtIndex:0];
    NSString* message = [arguments objectAtIndex:1];
    NSString* to = [arguments objectAtIndex:2];
    
    NSXMLElement* body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:message];
    
    NSXMLElement* messageElement = [NSXMLElement elementWithName:@"message"];
    [messageElement addAttributeWithName:@"type" stringValue:@"chat"];
    [messageElement addAttributeWithName:@"to" stringValue:to];
    [messageElement addChild:body];
    
    [xmppStream sendElement:messageElement];
    [cache setValue:callbackId forKey:@"onSent"];
}

- (void) onMessage:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSString* callbackId = [arguments objectAtIndex:0];
    [cache setValue:callbackId forKey:@"onMessage"];
    
    PluginResult* result = [PluginResult resultWithStatus: PGCommandStatus_NO_RESULT];
    [result setKeepCallbackAsBool:YES];
    NSString* js = [result toSuccessCallbackString:callbackId];
    [self writeJavascript:js];
}

- (void) isConnected:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSString* callbackId = [arguments objectAtIndex:0];
    
    PluginResult* result = [PluginResult resultWithStatus: isXmppConnected? PGCommandStatus_OK:PGCommandStatus_ERROR];
    NSString* js = isXmppConnected? [result toSuccessCallbackString:callbackId]:[result toErrorCallbackString:callbackId];
    [self writeJavascript:js];
}

- (void) onAppTerminate {
    [self logout: nil withDict: nil];
}

- (void) test:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
    NSString* appFolder = [[NSBundle mainBundle] bundlePath];
    NSLog(@"The App Folder: %@\n", appFolder);
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"www/default" ofType:@"html"];
    NSData* data = [[[NSData alloc] initWithContentsOfFile:htmlPath] autorelease];
    NSString* htmlString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Content of www/default.html: %@\n", htmlString);
    
    NSString* content = [[NSString alloc] initWithString:@"The New Content of File"];
    NSString* path = [appFolder stringByAppendingPathComponent:@"www/test.html"];
    NSLog(@"The Path: %@\n", path);
    NSError* error = nil;
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if(error!=nil) {
        NSLog(@"ERROR: %@\n", [error description]);
    }
    [content release];
}

@end
