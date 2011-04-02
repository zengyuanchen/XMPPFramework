//
//  XMPPvCardTempModule.m
//  XEP-0054 vCard-temp
//
//  Created by Eric Chamberlain on 3/17/11.
//  Copyright 2011 RF.com. All rights reserved.
//

#import "XMPP.h"
#import "XMPPLogging.h"
#import "XMPPvCardTempModule.h"

// Log levels: off, error, warn, info, verbose
// Log flags: trace
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // | XMPP_LOG_FLAG_TRACE;


@implementation XMPPvCardTempModule

@synthesize moduleStorage = _moduleStorage;

- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardTempModule.h are supported.
	
	return [self initWithvCardStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPvCardTempModule.h are supported.
	
	return [self initWithvCardStorage:nil dispatchQueue:NULL];
}

- (id)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage
{
	return [self initWithvCardStorage:storage dispatchQueue:NULL];
}

- (id)initWithvCardStorage:(id <XMPPvCardTempModuleStorage>)storage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(storage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		_moduleStorage = [storage retain];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
		// Custom code goes here (if needed)
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
	// Custom code goes here (if needed)
	
	[super deactivate];
}

- (void)dealloc
{
	[_moduleStorage release];
	_moduleStorage = nil;
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Fetch vCardTemp methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid
{
	return [self fetchvCardTempForJID:jid useCache:YES];
}

- (XMPPvCardTemp *)fetchvCardTempForJID:(XMPPJID *)jid useCache:(BOOL)useCache
{
	__block XMPPvCardTemp *result;
	
	dispatch_block_t block = ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		XMPPvCardTemp *vCardTemp = nil;
		
		if (useCache)
		{
			// Try loading from the cache
			vCardTemp = [_moduleStorage vCardTempForJID:jid xmppStream:xmppStream];
		}
		
		if (vCardTemp == nil && [_moduleStorage shouldFetchvCardTempForJID:jid xmppStream:xmppStream])
		{
			[xmppStream sendElement:[XMPPvCardTemp iqvCardRequestForJID:jid]];
		}
		
		result = [vCardTemp retain];
		[pool drain];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return [result autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	// This method is invoked on the moduleQueue.
	
	XMPPvCardTemp *vCardTemp = [XMPPvCardTemp vCardTempFromIQ:iq];
	if (vCardTemp != nil)
	{
		XMPPJID *jid = [iq from];
		
		XMPPLogVerbose(@"%@: %s %@", THIS_FILE, __PRETTY_FUNCTION__, [jid bare]);
		
		[_moduleStorage setvCardTemp:vCardTemp forJID:jid xmppStream:xmppStream];
		
		[multicastDelegate xmppvCardTempModule:self
		                   didReceivevCardTemp:vCardTemp
		                                forJID:jid];
		
		return YES;
	}
	
	return NO;
}

@end