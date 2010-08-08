//
//  DKExternalApplicationRegistration.m
//  Drag
//
//  Created by Zac White on 8/7/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKExternalApplicationRegistration.h"


@implementation DKExternalApplicationRegistration

@synthesize peerID, currentState, delegate;

- (void)setCurrentState:(DKExternalApplicaionState)newState {
	
	if (currentState == newState) return;
	
	currentState = newState;
	
	if ([self.delegate respondsToSelector:@selector(externalApplication:didChangeState:)]) {
		[self.delegate externalApplication:self didChangeState:self.currentState];
	}
}

- (void)dealloc {
	
	self.delegate = nil;
	self.peerID = nil;
	
	[super dealloc];
}

@end
