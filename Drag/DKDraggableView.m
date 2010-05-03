//
//  DKDraggableView.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDraggableView.h"

#import <QuartzCore/QuartzCore.h>

#import "DKDragDropServer.h"

@implementation DKDraggableView


- (id)initWithFrame:(CGRect)theFrame {
    if (!(self = [super initWithFrame:theFrame])) return nil;
	
	// Initialization code
	UILongPressGestureRecognizer *tapHoldRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPress:)];
	tapHoldRecognizer.cancelsTouchesInView = YES;
	[self addGestureRecognizer:tapHoldRecognizer];
	[tapHoldRecognizer release];
    
	return self;
}

- (void)_handleLongPress:(UIGestureRecognizer *)sender {
	//let the drag server know our frame and that we want to start dragging.
	[[DKDragDropServer sharedServer] displayDragWindowForDragView:self];
}

- (UIImage *)_generateImageForDrag {
	UIGraphicsBeginImageContext(self.bounds.size);
	
	[self.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	
	return resultingImage;
}

- (void)dealloc {
    [super dealloc];
}


@end
