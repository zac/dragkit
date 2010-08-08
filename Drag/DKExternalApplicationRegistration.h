//
//  DKExternalApplicationRegistration.h
//  Drag
//
//  Created by Zac White on 8/7/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DKApplicationRegistration.h"

typedef enum {
	DKExternalApplicaionStateIdle,
	DKExternalApplicaionStateRegistered,
	DKExternalApplicaionStateTransferring,
	DKExternalApplicaionStateDisconnected,
} DKExternalApplicaionState;

@class DKExternalApplicationRegistration;

@protocol DKExternalApplicationRegistrationDelegate

// called when the connection state of an external application changes.
- (void)externalApplication:(DKExternalApplicationRegistration *)application didChangeState:(DKExternalApplicaionState)state;

// called when more application registration information has been obtained.
- (void)externalApplicationDidUpdateRegistration:(DKExternalApplicationRegistration *)applicationRegistration;

@end


@interface DKExternalApplicationRegistration : DKApplicationRegistration {
	NSString *peerID;
	DKExternalApplicaionState currentState;
	
	NSObject<DKExternalApplicationRegistrationDelegate> *delegate;
}

@property (nonatomic, copy) NSString *peerID;
@property DKExternalApplicaionState currentState;

@property (nonatomic, assign) NSObject<DKExternalApplicationRegistrationDelegate> *delegate;

@end
