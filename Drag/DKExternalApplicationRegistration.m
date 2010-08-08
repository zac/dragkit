//
//  DKExternalApplicationRegistration.m
//  Drag
//
//  Created by Zac White on 8/7/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKExternalApplicationRegistration.h"


@implementation DKExternalApplicationRegistration

@synthesize peerID, currentState;

- (void)dealloc {
	
	self.peerID = nil;
	
	[super dealloc];
}

@end
