//
//  DKDragServer.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//
//  Singleton code stolen from: http://boredzo.org/blog/archives/2009-06-17/doing-it-wrong

#import "DKDragDropServer.h"

static DKDragDropServer *sharedInstance = nil;

@implementation DKDragDropServer

@synthesize dragWindowVisible;

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
#pragma mark Window Creation

- (void)displayDragWindowForDragView:(UIView<DKDraggableViewProtocol> *)draggableView {
	
	if (self.dragWindowVisible) {
		//we already have a window visisble...multitouch support coming soon?
		return;
	}
	
	//grab the image.
	UIImage *dragImage = [draggableView _generateImageForDrag];
	
	CGPoint viewPositionInWindow = [draggableView convertPoint:draggableView.frame.origin toView:[draggableView window]];
	UIWindow *dragWindow = [[UIWindow alloc] initWithFrame:CGRectMake(viewPositionInWindow.x, viewPositionInWindow.y, dragImage.size.width, dragImage.size.height)];
	UIImageView *dragImageView = [[UIImageView alloc] initWithFrame:dragWindow.bounds];
	dragImageView.image = dragImage;
	
	dragWindow.alpha = .7;
	
	self.dragWindowVisible = YES;
	
	[dragWindow makeKeyAndVisible];
	NSLog(@"made window: %@ visible", dragWindow);
}

@end
