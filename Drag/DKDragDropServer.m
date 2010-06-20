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

@interface DKDragDropServer (DKPrivate)

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender;
- (UIImage *)dk_generateImageForDragFromView:(UIView *)theView;
- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point;
- (void)dk_moveDragViewToPoint:(CGPoint)point;

@end


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
	
	UILongPressGestureRecognizer *dragRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
	dragRecognizer.minimumPressDuration = 0.1;
	dragRecognizer.numberOfTapsRequired = 1;
	
	[draggableView addGestureRecognizer:dragRecognizer];
	[dragRecognizer release];
}

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDropDelegate> *)dropDelegate {
	
}

#pragma mark -
#pragma mark Dragging Callback

CGSize touchOffset;

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender {
	//let the drag server know our frame and that we want to start dragging.
	
	CGPoint touchPoint = [sender locationInView:[self.originalView window]];
	CGPoint viewPosition;
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan:
			
			// create the necessary view and animate it.
			
			self.originalView = [sender view];
			
			touchOffset = CGSizeMake(104, 39);
			
			CGPoint position = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);
			
			[self dk_displayDragViewForView:self.originalView atPoint:position];
			
			break;
		case UIGestureRecognizerStateChanged:
			
			// move the view to any point the sender is.
			// check for drop zones and light them up if necessary.
			
			viewPosition = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);
			
			[self dk_moveDragViewToPoint:viewPosition];
			
			break;
		case UIGestureRecognizerStateRecognized:
			
			NSLog(@"recognized");
			// the user has let go.
			// TODO: actually drop if on drop zone.
			[self cancelDrag];
			
			break;
		case UIGestureRecognizerStateCancelled:
			
			NSLog(@"cancelled");
			// something happened and we need to cancel.
			[self cancelDrag];
			
			break;
		default:
			break;
	}
}

//we are going to zoom from this image to the normal view for the content type.

- (UIImage *)dk_generateImageForDragFromView:(UIView *)theView {
	UIGraphicsBeginImageContext(theView.bounds.size);
	
	[theView.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	
	return resultingImage;
}

#pragma mark -
#pragma mark Drag View Creation

- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point {
	if (!self.draggedView) {
		NSLog(@"creating view with view: %@ at point: %@", draggableView, NSStringFromCGPoint(point));
		
		//grab the image.
		UIImage *dragImage = [self dk_generateImageForDragFromView:draggableView];
		
		//transition from the dragImage to our view.
		
		UIImage *background = [UIImage imageNamed:@"drag_view_background.png"];
		
		//CGPoint originalViewOrigin = [[self.originalView superview] convertPoint:self.originalView.frame.origin toView:[self.originalView window]];
		
		// create our drag view where we want it.
		self.draggedView = [[[UIView alloc] initWithFrame:CGRectMake(point.x,
																	 point.y,
																	 background.size.width,
																	 background.size.height)] autorelease];
		
		// then apply a translate and a scale to make it the size/location of the original view.
		
		// remove the offset.
		CGPoint translationPoint = [[self.originalView window] convertPoint:CGPointMake(point.x + touchOffset.width, point.y + touchOffset.height)
																	 toView:self.originalView];
		
		// add back in the offset.
		translationPoint.x = translationPoint.x - touchOffset.width;
		translationPoint.y = translationPoint.y - touchOffset.height;
		
		NSLog(@"translate: %@", NSStringFromCGPoint(translationPoint));
		
		float widthRatio = self.originalView.frame.size.width / self.draggedView.frame.size.width;
		float heightRatio = self.originalView.frame.size.height / self.draggedView.frame.size.height;
		
		float widthDiff = self.originalView.frame.size.width - self.draggedView.frame.size.width;
		float heightDiff = self.originalView.frame.size.height - self.draggedView.frame.size.height;
		
		self.draggedView.transform = CGAffineTransformMakeTranslation(-translationPoint.x + widthDiff / 2.0, -translationPoint.y + heightDiff / 2.0);
		self.draggedView.transform = CGAffineTransformScale(self.draggedView.transform,
															widthRatio,
															heightRatio);
		
		
		//originally the large size.
		//will animate down.
		UIImageView *dragImageView = [[UIImageView alloc] initWithFrame:self.draggedView.bounds];
		dragImageView.image = background;
		
		UIImageView *originalImageView = [[UIImageView alloc] initWithFrame:self.draggedView.bounds];
		originalImageView.image = dragImage;
		
		[self.draggedView addSubview:dragImageView];
		[self.draggedView addSubview:originalImageView];
		
		originalImageView.alpha = 1.0;
		dragImageView.alpha = 0.0;
		
		[[draggableView window] addSubview:self.draggedView];
		
		[UIView beginAnimations:@"ResizeDragView" context:originalImageView];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(cancelAnimationDidStop:finished:context:)];
		
		//snap it to normal.
		self.draggedView.transform = CGAffineTransformIdentity;
		
		dragImageView.alpha = 1.0;
		originalImageView.alpha = 0.0;
		
		[UIView commitAnimations];
		
		[dragImageView release];
		[originalImageView release];
		
		
		//TODO: Animate on screen.
	}
}

- (void)dk_moveDragViewToPoint:(CGPoint)point {
	
	if (!self.draggedView) {
		NSLog(@"ERROR: No drag view.");
	}
	
	self.draggedView.frame = CGRectMake(point.x, point.y, self.draggedView.frame.size.width, self.draggedView.frame.size.height);
}

- (void)cancelDrag {
	//cancel the window by animating it back to its location.
	
	CGPoint originalLocation = [[self.originalView superview] convertPoint:self.originalView.center toView:[self.originalView window]];
	
	[UIView beginAnimations:@"SnapBack" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.3];
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
	
	if ([animationID isEqualToString:@"SnapBack"]) {
		[self.draggedView removeFromSuperview];
		self.draggedView = nil;
	} else if ([animationID isEqualToString:@"ResizeDragView"]) {
		[(UIView *)context removeFromSuperview];
	}
}

@end
