//
//  XMPP.h
//
//  Created by Ryan on 14/10/2011.
//  Copyright 2011 Ryan Hubert. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifdef PHONEGAP_FRAMEWORK
#import <PhoneGap/PGPlugin.h>
#else
#import "PGPlugin.h"
#endif
#import "XMPP.h"
#import "XMPPReconnect.h"


@interface XMPPClient : PGPlugin {
    XMPPStream *xmppStream;
	XMPPReconnect *xmppReconnect;
    
    BOOL allowSelfSignedCertificates;
	BOOL allowSSLHostNameMismatch;
    BOOL isXmppConnected;
    
    NSMutableDictionary* cache;
}

@property (nonatomic, readonly) XMPPStream *xmppStream;
@property (nonatomic, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, readonly) BOOL allowSelfSignedCertificates;
@property (nonatomic, readonly) BOOL allowSSLHostNameMismatch;
@property (nonatomic, readonly) BOOL isXmppConnected;

- (void) login:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) logout:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) send:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) onMessage:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void) isConnected:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end
