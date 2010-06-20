//
//  DKDragServer.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//
//  Singleton code stolen from: http://boredzo.org/blog/archives/2009-06-17/doing-it-wrong

#import "DKDragDropServer.h"

#import "DKDropTarget.h"

#import <QuartzCore/QuartzCore.h>

static DKDragDropServer *sharedInstance = nil;

@interface DKDragDropServer (DKPrivate)

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender;
- (UIImage *)dk_generateImageForDragFromView:(UIView *)theView;
- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point;
- (void)dk_moveDragViewToPoint:(CGPoint)point;
- (void)dk_messageTargetsHitByPoint:(CGPoint)point;
- (void)dk_setView:(UIView *)view highlighted:(BOOL)highlighted animated:(BOOL)animated;

@end


@implementation DKDragDropServer

@synthesize draggedView, originalView, drawerController, drawerVisibilityLevel;

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
			dk_dropTargets = [[NSMutableArray alloc] init];
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
	// maybe add to hash table?
	// Initialization code
	
	UILongPressGestureRecognizer *dragRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
	dragRecognizer.minimumPressDuration = 0.1;
	dragRecognizer.numberOfTapsRequired = 1;
	
	[draggableView addGestureRecognizer:dragRecognizer];
	[dragRecognizer release];
}

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDropDelegate> *)dropDelegate {
	
	DKDropTarget *dropTarget = [[DKDropTarget alloc] init];
	dropTarget.dropView = dropView;
	dropTarget.dropDelegate = dropDelegate;
	
	[dk_dropTargets addObject:dropTarget];
	[dropTarget release];
}

#pragma mark -
#pragma mark Dragging Callback

#define MARGIN_Y (50)

#define PEEK_DISTANCE (30)
#define VISIBLE_WIDTH (300)

CGSize touchOffset;

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender {
	// let the drag server know our frame and that we want to start dragging.
	
	CGPoint touchPoint = [sender locationInView:[self.originalView window]];
	CGPoint viewPosition;
	CGFloat windowWidth;
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan:
			
			// create the necessary view and animate it.
			
			self.originalView = [sender view];
			
			touchOffset = CGSizeMake(104, 39);
			
			CGPoint position = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);
			
			[self dk_displayDragViewForView:self.originalView atPoint:position];
			
			self.drawerVisibilityLevel = DKDrawerVisibilityLevelPeeking;
			
			break;
		case UIGestureRecognizerStateChanged:
			
			// move the view to any point the sender is.
			// check for drop zones and light them up if necessary.
			
			windowWidth = [[self.originalView window] frame].size.width;
			
			[self dk_messageTargetsHitByPoint:touchPoint];
			
			if (touchPoint.x > windowWidth - 100) {
				self.drawerVisibilityLevel = DKDrawerVisibilityLevelVisible;
			} else if (self.drawerVisibilityLevel == DKDrawerVisibilityLevelVisible && touchPoint.x < windowWidth - VISIBLE_WIDTH) {
				self.drawerVisibilityLevel = DKDrawerVisibilityLevelPeeking;
			}
			
			viewPosition = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);
			
			[self dk_moveDragViewToPoint:viewPosition];
			
			break;
		case UIGestureRecognizerStateRecognized:
			
			// the user has let go.
			// TODO: actually drop if on drop zone.
			[self cancelDrag];
			
			break;
		case UIGestureRecognizerStateCancelled:
			
			// something happened and we need to cancel.
			[self cancelDrag];
			
			break;
		default:
			break;
	}
}

- (void)setDrawerVisibilityLevel:(DKDrawerVisibilityLevel)newLevel {
	
	if (newLevel == drawerVisibilityLevel) return;
	
	drawerVisibilityLevel = newLevel;
	
	CGRect windowFrame = [[self.originalView window] frame];
	
	if (!self.drawerController) {
		self.drawerController = [[[DKDrawerViewController alloc] init] autorelease];
		self.drawerController.view.frame = CGRectMake(windowFrame.size.width,
													  MARGIN_Y,
													  VISIBLE_WIDTH,
													  windowFrame.size.height - 2 * MARGIN_Y);
		[[self.originalView window] addSubview:self.drawerController.view];
		
		[[self.draggedView superview] bringSubviewToFront:self.draggedView];
	}
	
	CGFloat drawerX = 0.0;
	//TODO: Support different anchor points.
	switch (drawerVisibilityLevel) {
		case DKDrawerVisibilityLevelHidden:
			drawerX = windowFrame.size.width;
			break;
		case DKDrawerVisibilityLevelPeeking:
			drawerX = windowFrame.size.width - PEEK_DISTANCE;
			break;
		case DKDrawerVisibilityLevelVisible:
			drawerX = windowFrame.size.width - VISIBLE_WIDTH;
			break;
		default:
			break;
	}
	
	[UIView beginAnimations:@"DrawerMove" context:NULL];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:0.3];
	
	self.drawerController.view.frame = CGRectMake(drawerX,
												  MARGIN_Y,
												  VISIBLE_WIDTH,
												  windowFrame.size.height - 2 * MARGIN_Y);
	
	[UIView commitAnimations];
}

- (void)dk_messageTargetsHitByPoint:(CGPoint)point {
	//go through the drop targets and find out of the point is in any of those rects.
	
	int targetIndex = 0;
	for (DKDropTarget *target in dk_dropTargets) {
		//convert target rect to the window's coordinates.
		if (CGRectContainsPoint(target.frameInWindow, point)) {
			//message the target.
			
			target.containsDragView = YES;
			
			//TODO: Make the DKDropTarget message the view?
			
			[self dk_setView:target.dropView highlighted:YES animated:YES];
			
			[target.dropDelegate dragDidEnterTargetView:target.dropView];
			
		} else if (target.containsDragView) {
			//it just left.
			
			target.containsDragView = NO;
			
			[self dk_setView:target.dropView highlighted:NO animated:YES];
			
			[target.dropDelegate dragDidLeaveTargetView:target.dropView];
		}
		targetIndex++;
	}
}

- (void)dk_setView:(UIView *)view highlighted:(BOOL)highlighted animated:(BOOL)animated {
	
	CALayer *theLayer = view.layer;
	
	if (animated) {
		[UIView beginAnimations: @"HighlightView" context: NULL];
		[UIView setAnimationCurve: UIViewAnimationCurveLinear];
		[UIView setAnimationBeginsFromCurrentState: YES];
	}
	
	// taken from AQGridView.
	if ([theLayer respondsToSelector: @selector(setShadowPath:)] && [theLayer respondsToSelector: @selector(shadowPath)]) {
		
		if (highlighted) {
			CGMutablePathRef path = CGPathCreateMutable();
			CGPathAddRect( path, NULL, theLayer.bounds );
			theLayer.shadowPath = path;
			CGPathRelease( path );
			
			theLayer.shadowOffset = CGSizeZero;
			
			theLayer.shadowColor = [[UIColor darkGrayColor] CGColor];
			theLayer.shadowRadius = 12.0;
			
			theLayer.shadowOpacity = 1.0;
			
		} else {
			theLayer.shadowOpacity = 0.0;
		}
	}
	
	if (animated) [UIView commitAnimations];
}

// we are going to zoom from this image to the normal view for the content type.

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
		
		// grab the image.
		UIImage *dragImage = [self dk_generateImageForDragFromView:draggableView];
		
		// transition from the dragImage to our view.
		
		UIImage *background = [UIImage imageNamed:@"drag_view_background.png"];
		
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
		
		float widthRatio = self.originalView.frame.size.width / self.draggedView.frame.size.width;
		float heightRatio = self.originalView.frame.size.height / self.draggedView.frame.size.height;
		
		float widthDiff = self.originalView.frame.size.width - self.draggedView.frame.size.width;
		float heightDiff = self.originalView.frame.size.height - self.draggedView.frame.size.height;
		
		self.draggedView.transform = CGAffineTransformMakeTranslation(-translationPoint.x + widthDiff / 2.0, -translationPoint.y + heightDiff / 2.0);
		self.draggedView.transform = CGAffineTransformScale(self.draggedView.transform,
															widthRatio,
															heightRatio);
		
		
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
		
		// snap it to normal.
		self.draggedView.transform = CGAffineTransformIdentity;
		
		dragImageView.alpha = 1.0;
		originalImageView.alpha = 0.0;
		
		[UIView commitAnimations];
		
		[dragImageView release];
		[originalImageView release];
	}
}

- (void)dk_moveDragViewToPoint:(CGPoint)point {
	
	if (!self.draggedView) {
		NSLog(@"ERROR: No drag view.");
		return;
	}
	
	self.draggedView.frame = CGRectMake(point.x, point.y, self.draggedView.frame.size.width, self.draggedView.frame.size.height);
}

- (void)cancelDrag {
	// cancel the window by animating it back to its location.
	
	CGPoint originalLocation = [[self.originalView superview] convertPoint:self.originalView.center toView:[self.originalView window]];
	
	[UIView beginAnimations:@"SnapBack" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(cancelAnimationDidStop:finished:context:)];
	
	// go back to original size.
	
	// move back to original location.
	self.draggedView.center = originalLocation;
	
	// fade out.
	self.draggedView.alpha = 0.5;
	
	[UIView commitAnimations];
	
	self.drawerVisibilityLevel = DKDrawerVisibilityLevelHidden;
}

- (void)cancelAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	
	if ([animationID isEqualToString:@"SnapBack"]) {
		[self.draggedView removeFromSuperview];
		self.draggedView = nil;
	} else if ([animationID isEqualToString:@"ResizeDragView"]) {
		[(UIView *)context removeFromSuperview];
	}
}

- (void)dealloc {
	
	[dk_dropTargets release];
	
	[super dealloc];
}

@end
