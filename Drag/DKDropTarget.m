//
//  DKDropTarget.m
//  Drag
//
//  Created by Zac White on 6/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDropTarget.h"


@implementation DKDropTarget

@synthesize dropView, dropDelegate, containsDragView;
@dynamic frameInWindow;

- (id)init {
	if (!(self = [super init])) return nil;
	
	self.containsDragView = NO;
	
	return self;
}

- (CGRect)frameInWindow {
	return [[self.dropView superview] convertRect:self.dropView.frame toView:[self.dropView window]];
}

- (void)dealloc {
	
	self.dropView = nil;
	self.dropDelegate = nil;
	
	[super dealloc];
}

@end
