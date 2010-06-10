//
//  DKDragServer.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//
//  Singleton code stolen from: http://boredzo.org/blog/archives/2009-06-17/doing-it-wrong

#import "DKDragDropServer.h"

#import <QuartzCore/QuartzCore.h>

static DKDragDropServer *sharedInstance = nil;

@implementation DKDragDropServer

@synthesize draggedView, originalView;

#pragma mark -
#pragma mark Singleton

+ (void)initialize {
	if (!sharedInstance) {
		[[self alloc] init];
	}
}

+ (id)sharedServer {
	//already created by +initialize
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
	if (sharedInstance) {
		//The caller expects to receive a new object, so implicitly retain it to balance out the caller's eventual release message.
		return [sharedInstance retain];
	} else {
		//When not already set, +initialize is our caller—it's creating the shared instance. Let this go through.
		return [super allocWithZone:zone];
	}
}

- (id) init {
	//If sharedInstance is nil, +initialize is our caller, so initialize the instance.
	//Conversely, if it is not nil, release this instance (if it isn't the shared instance) and return the shared instance.
	if (!sharedInstance) {
		if ((self = [super init])) {
			//Initialize the instance here.
		}
		
		//Assign sharedInstance here so that we don't end up with multiple instances if a caller calls +alloc/-init without going through +sharedInstance.
		//This isn't foolproof, however (especially if you involve threads). The only correct way to get an instance of a singleton is through the +sharedInstance method.
		sharedInstance = self;
	} else if (self != sharedInstance) {
		[self release];
		self = sharedInstance;
	}
	
	return self;
}

#pragma mark -
#pragma mark Marking Views

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dropDataSource {
    [self markViewAsDraggable:draggableView forDrag:nil withDataSource:dropDataSource];
}

/* Optional parameter for drag identification. */
- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dropDataSource {
	//maybe add to hash table?
	// Initialization code
	DKDragGestureRecognizer *dragRecognizer = [[DKDragGestureRecognizer alloc] initWithDragDelegate:self];
	
	[draggableView addGestureRecognizer:dragRecognizer];
	[dragRecognizer release];
}

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDropDelegate> *)dropDelegate {
	
}

#pragma mark -
#pragma mark Drag Delgeate Callbacks

- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	// assign the current view to the dragging view.
	self.originalView = [recognizer view];
}

- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	CGPoint newPoint = [[touches anyObject] locationInView:[[recognizer view] window]];
	NSLog(@"moving to point: %@", NSStringFromCGPoint(newPoint));
	[self moveDragViewForView:self.originalView toPoint:newPoint];
}

- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	// if the view is within a drop zone, animate to the drop zone.
	// else, cancel.
	
	// for now just cancel.
	[self cancelDrag];
}

- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	// cancel the drag.
	[self cancelDrag];
}

- (void)_handleLongPress:(UIGestureRecognizer *)sender {
	//let the drag server know our frame and that we want to start dragging.
	NSLog(@"GESTURE OVER: %@", sender);
}

- (UIImage *)_generateImageForDragFromView:(UIView *)theView {
	UIGraphicsBeginImageContext(theView.bounds.size);
	
	[theView.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	
	return resultingImage;
}

#pragma mark -
#pragma mark Drag View Creation

- (void)moveDragViewForView:(UIView *)draggableView toPoint:(CGPoint)point {
	if (!self.draggedView) {
		NSLog(@"creating view with view: %@", draggableView);
		
		//grab the image.
		UIImage *dragImage = [self _generateImageForDragFromView:draggableView];
		
		CGPoint viewPositionInWindow = [self.draggedView convertPoint:self.draggedView.frame.origin toView:[self.draggedView window]];
		self.draggedView = [[[UIView alloc] initWithFrame:CGRectMake(viewPositionInWindow.x, viewPositionInWindow.y, dragImage.size.width, dragImage.size.height)] autorelease];
		
		UIImageView *dragImageView = [[UIImageView alloc] initWithFrame:self.draggedView.bounds];
		dragImageView.image = dragImage;
		
		[self.draggedView addSubview:dragImageView];
		[dragImageView release];
		
		[[self.draggedView window] addSubview:self.draggedView];
	}
	
	if (point.x <= 0) {
		[self cancelDrag];
		return;
	}
	
	self.draggedView.frame = CGRectMake(point.x, point.y, self.draggedView.frame.size.width, self.draggedView.frame.size.height);
	
}

- (void)cancelDrag {
	//cancel the window by animating it back to its location.
	
	CGPoint originalLocation = [self.originalView convertPoint:self.originalView.center toView:[self.originalView window]];
	
	[UIView beginAnimations:@"SnapBack" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(cancelAnimationDidStop:finished:context:)];
	
	//go back to original size.
	
	//move back to original location.
	self.draggedView.center = originalLocation;
	
	//fade out.
	self.draggedView.alpha = 0.5;
	
	[UIView commitAnimations];
}

- (void)cancelAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {	
	[self.draggedView removeFromSuperview];
	self.draggedView = nil;
}

@end
