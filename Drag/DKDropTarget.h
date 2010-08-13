//
//  DKDropTarget.h
//  Drag
//
//  Created by Zac White on 6/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DKDragDropServer.h"

@interface DKDropTarget : NSObject {
	UIView *dropView;
	NSObject<DKDragDelegate> *dragDelegate;
	
	NSArray *acceptedTypes;
	
	CGRect frameInWindow;
	
	BOOL containsDragView;
}

@property (nonatomic, retain) UIView *dropView;
@property (nonatomic, assign) NSObject<DKDragDelegate> *dragDelegate;
@property (nonatomic, readonly) CGRect frameInWindow;

@property (nonatomic, copy) NSArray *acceptedTypes;

@property (nonatomic) BOOL containsDragView;

@end
