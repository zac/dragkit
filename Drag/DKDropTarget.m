//
//  DKDropTarget.m
//  Drag
//
//  Created by Zac White on 6/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDropTarget.h"


@implementation DKDropTarget
@synthesize dropView, dropDelegate, frameInWindow, containsDragView;

- (id)init {
	if (!(self = [super init])) return nil;
	
	self.frameInWindow = CGRectZero;
	self.containsDragView = NO;
	
	return self;
}

- (CGRect)frameInWindow {
	if (CGRectEqualToRect(frameInWindow, CGRectZero)) {
		frameInWindow = [[self.dropView superview] convertRect:self.dropView.frame toView:[self.dropView window]];
	}
	
	return frameInWindow;
}

- (void)dealloc {
	
	self.dropView = nil;
	self.dropDelegate = nil;
	
	[super dealloc];
}

@end
