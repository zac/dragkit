//
//  DKDragGestureRecognizer.m
//  Drag
//
//  Created by Zac White on 6/9/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDragGestureRecognizer.h"


@implementation DKDragGestureRecognizer

@synthesize dragDelegate;
@synthesize numberOfTapsRequired, numberOfTouchesRequired;

- (id)initWithDragDelegate:(NSObject<DKDragGestureRecognizerDelegate> *)newDelegate {
	if (!(self = [super initWithTarget:self action:@selector(_longPressDone:)])) return nil;
	
	// assign the delegate.
	self.dragDelegate = newDelegate;
	
	// require 2 taps to begin a drag.
	self.numberOfTapsRequired = 2;
	
	// require 1 finger to begin a drag.
	self.numberOfTouchesRequired = 1;
	
	// set our allowable movement high because we want user to be able to
	// double-tap and move very quickly.
	//self.allowableMovement = 10000;
	
	// more research on this required...
	self.cancelsTouchesInView = YES;
	
	return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	NSLog(@"%s", _cmd);
	
	[self.dragDelegate dragRecognizer:self touchesBegan:touches withEvent:event];
	
	[super touchesBegan:touches withEvent:event];
}

- (void)_longPressDone:(id)sender {
	//TODO: Fix this to not be nil.
	NSLog(@"longPressDone:%@", sender);
	[self.dragDelegate dragRecognizer:self touchesBegan:nil withEvent:nil];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	NSLog(@"%s", _cmd);
	
	[self.dragDelegate dragRecognizer:self touchesMoved:touches withEvent:event];
	
	// I think we want possible.
	// TODO: Check if this needs to be UIGestureRecognizerStateChanged.
	//self.state = UIGestureRecognizerStatePossible;
	
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	NSLog(@"%s", _cmd);
	
	[self.dragDelegate dragRecognizer:self touchesEnded:touches withEvent:event];
	
	self.state = UIGestureRecognizerStateEnded;
	
	[super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	NSLog(@"%s", _cmd);
	
	[self.dragDelegate dragRecognizer:self touchesCancelled:touches withEvent:event];
	
	[super touchesCancelled:touches withEvent:event];
}

- (void)dealloc {
	
	self.dragDelegate = nil;
	
	[super dealloc];
}

@end
