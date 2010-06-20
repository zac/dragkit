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
	NSObject<DKDropDelegate> *dropDelegate;
	
	CGRect frameInWindow;
	
	BOOL containsDragView;
}

@property (nonatomic, retain) UIView *dropView;
@property (nonatomic, assign) NSObject<DKDropDelegate> *dropDelegate;
@property (nonatomic) CGRect frameInWindow;

@property (nonatomic) BOOL containsDragView;

@end
