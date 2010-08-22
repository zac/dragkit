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

#import "DKApplicationRegistration.h"

#import <QuartzCore/QuartzCore.h>

#import <objc/runtime.h>

static DKDragDropServer *sharedInstance = nil;

@interface DKDragDropServer (DKPrivate)

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender;
- (UIImage *)dk_generateImageForDragFromView:(UIView *)theView;
- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point;
- (void)dk_moveDragViewToPoint:(CGPoint)point;
- (void)dk_createDragPasteboardForView:(UIView *)view;
- (void)dk_messageTargetsHitByPoint:(CGPoint)point;
- (void)dk_setView:(UIView *)view highlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)dk_handleURL:(NSNotification *)notification;
- (UIWindow *)dk_mainAppWindow;
- (DKDropTarget *)dk_dropTargetHitByPoint:(CGPoint)point;
- (void)dk_collapseDragViewAtPoint:(CGPoint)point;

@end

@implementation DKDragDropServer

@synthesize draggedView, originalView, pausedTimer;

#pragma mark -
#pragma mark Singleton

+ (void)initialize {
	if (!sharedInstance) {
		//TODO: Check for plist entries for supported types.
		[[self alloc] init];
	}
}

+ (id)sharedServer {
	//already created by +initialize
	return sharedInstance;
}

+ (NSString *)versionString {
	return @"1.0";
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
			
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(dk_applicationWillTerminate:)
														 name:UIApplicationWillTerminateNotification
													   object:nil];
			pausedTimer = nil;
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

- (UIWindow *)dk_mainAppWindow {
	if (dk_mainAppWindow) return dk_mainAppWindow;
	
	//TODO: Better logic to determine the app window.
	dk_mainAppWindow = [[[UIApplication sharedApplication] keyWindow] retain];
	
	if (!dk_mainAppWindow) {
		NSLog(@"UH OH! TOO SOON!");
	}
	
	return dk_mainAppWindow;
}

- (void)dk_applicationWillTerminate:(NSNotification *)notification {
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:@"dragkit-drag" create:NO];
	if (dragPasteboard) dragPasteboard.persistent = YES;
}

#define MAX_NUMBER_OF_REGISTERED_APPS 100

- (void)registerApplicationWithTypes:(NSArray *)types {
	
	NSLog(@"reg: %@", types);
	
	if (dk_manifest) {
		NSLog(@"dk_buildManifest should only be called once.");
		return;
	}
	
	dk_manifest = [[NSMutableArray alloc] init];
	
	// check to see if we've already created a pasteboard. this returns a valid pasteboard in the common case.
	NSString *pasteboardName = [[NSUserDefaults standardUserDefaults] objectForKey:@"dragkit-pasteboard"];
	
	// create our app registration.
	DKApplicationRegistration *appRegistration = [DKApplicationRegistration registrationWithDragTypes:types];
	
	[dk_applicationRegistration release];
	dk_applicationRegistration = [appRegistration retain];
	
	// the original application that created the manifest could have been deleted.
	// this would leave UIPasteboards out there without a central manifest.
	// we must scan through the possible application registration slots and recreate the manifest.
	// of course, we could be the first app. In that case, we'll scan through and just create the manifest
	// pointing to just our app's registration data.
	
	BOOL registrationInserted = NO;
	
	for (int i = 0; i < MAX_NUMBER_OF_REGISTERED_APPS; i++) {
		UIPasteboard *possibleApp = [UIPasteboard pasteboardWithName:[NSString stringWithFormat:@"dragkit-application:%d", i] create:YES];
		if ([possibleApp containsPasteboardTypes:[NSArray arrayWithObject:@"dragkit.registration"]]) {
			
			// if it is our pasteboard, don't bother.
			// pasteboardName could be nil if we haven't been launched.
			// in that case, we'll just insert into our registration which happens in the else block.
			if ([possibleApp.name isEqualToString:pasteboardName]) continue;
			
			[dk_manifest addObject:possibleApp.name];
			
		} else if (!pasteboardName && !registrationInserted) {
			registrationInserted = YES;
			
			[[NSUserDefaults standardUserDefaults] setObject:[possibleApp name] forKey:@"dragkit-pasteboard"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			// insert our application registration.
			// create a new pasteboard with the name [possibleApp name].
			UIPasteboard *registrationPasteboard = [UIPasteboard pasteboardWithName:[possibleApp name] create:YES];
			registrationPasteboard.persistent = YES;
			
			NSData *registrationData = [NSKeyedArchiver archivedDataWithRootObject:appRegistration];
			
			[registrationPasteboard setData:registrationData forPasteboardType:@"dragkit.registration"];
		}
	}
	
	// we should always have an available slot.
	// if we don't, we've run out of slots and probably should have picked a higher number than 100.
	if (!pasteboardName && !registrationInserted) {
		NSLog(@"ERROR: All available app registration slots are used.");
	}
}

- (NSArray *)registeredApplications {
	//returns all registered applications.
	
	if (dk_supportedApplications) return [[dk_supportedApplications retain] autorelease];
	
	NSAssert(dk_manifest, @"Expected a DragKit manifest to already be created.");
	
	dk_supportedApplications = [[NSMutableArray alloc] init];
	for (NSString *pasteboardName in dk_manifest) {
		
		UIPasteboard *registrationPasteboard = [UIPasteboard pasteboardWithName:pasteboardName create:YES];
		
		NSData *pasteboardData = [registrationPasteboard dataForPasteboardType:@"dragkit.registration"];
		
		if (pasteboardData) {
			DKApplicationRegistration *appRegistration = [NSKeyedUnarchiver unarchiveObjectWithData:pasteboardData];
			[dk_supportedApplications addObject:appRegistration];
		}
	}
	
	NSLog(@"registered apps: %@", dk_supportedApplications);
	
	return [[dk_supportedApplications retain] autorelease];
}

- (void)resetRegistrationDatabase {
	[UIPasteboard removePasteboardWithName:@"dragkit-manifest"];
	
	for (int i = 0; i < MAX_NUMBER_OF_REGISTERED_APPS; i++) {
		[UIPasteboard removePasteboardWithName:[NSString stringWithFormat:@"dragkit-application:%d", i]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"dragkit-pasteboard"];
}

#pragma mark -
#pragma mark Marking Views

// the key for our associated object.
static char dragKey;
static char contextKey;
static char dataProviderKey;

- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource context:(void *)context {
	// Initialization code
	
	UILongPressGestureRecognizer *dragRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
	dragRecognizer.minimumPressDuration = 0.1;
	dragRecognizer.numberOfTapsRequired = 1;
	
	[draggableView addGestureRecognizer:dragRecognizer];
	[dragRecognizer release];
	
	// use associated objects to attach our drag identifier.
	objc_setAssociatedObject(draggableView, &dragKey, dragID, OBJC_ASSOCIATION_COPY_NONATOMIC);
	
	// use associated objects to attach our context.
	objc_setAssociatedObject(draggableView, &contextKey, context, OBJC_ASSOCIATION_ASSIGN);
	
	// attach the drag delegate.
	objc_setAssociatedObject(draggableView, &dataProviderKey, dragDataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate {
	
	DKDropTarget *dropTarget = [[DKDropTarget alloc] init];
	dropTarget.dropView = dropView;
	dropTarget.dragDelegate = dropDelegate;
	dropTarget.acceptedTypes = types;
	
	[dk_dropTargets addObject:dropTarget];
	[dropTarget release];
}

- (void)unmarkViewAsDraggable:(UIView *)draggableView {
	// clear our associated objects.
	objc_setAssociatedObject(draggableView, &dragKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(draggableView, &contextKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(draggableView, &dataProviderKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (void)unmarkDropTarget:(UIView *)dropView {
	
	DKDropTarget *targetToRemove = nil;
	for (DKDropTarget *target in dk_dropTargets) {
		if (dropView == target.dropView) {
			targetToRemove = target;
			break;
		}
	}
	
	if (targetToRemove) [dk_dropTargets removeObject:targetToRemove];
}

- (void)dk_createDragPasteboardForView:(UIView *)view {
	//grab the associated objects.
	NSString *dropIdentifier = objc_getAssociatedObject(view, &dragKey);
	void *dropContext = objc_getAssociatedObject(view, &contextKey);
	NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
	
	// ask for the data and construct a UIPasteboard.
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:@"dragkit-drag" create:YES];
	
	// associate metadata with the pasteboard.
	NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
	
	// add the drag image. if none is set, we can use default.
	// [metadata setObject:[NSData data] forKey:@"dragImage"];
	
	// add the registration for the application that we're dragging from.
	[metadata setObject:dk_applicationRegistration forKey:@"draggingApplication"];
	
	// set the date so we know the drag happened a reasonable time ago in the receiving app.
	[metadata setObject:[NSDate date] forKey:@"dragDate"];
	
	// set our metadata on our private metadata type.
	[dragPasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:metadata] forPasteboardType:@"dragkit.metadata"];
	[metadata release];
	
	// go through each type supported by the drop target
	// and request the data for that type from the data source.
	
	NSArray *advertisedTypes = [dataProvider typesSupportedForDrag:dropIdentifier forView:view context:dropContext];
	
	for (NSString *type in advertisedTypes) {
		NSData *data = [dataProvider dataForType:type withDrag:dropIdentifier forView:view context:dropContext];
		
		if (data) {
			[dragPasteboard addItems:[NSArray arrayWithObject:[NSDictionary dictionaryWithObject:data forKey:type]]];
		}
	}
}

#pragma mark -
#pragma mark Dragging Callback

#define MARGIN_Y (50)

CGSize touchOffset;
- (void)dk_springboardOpenItemFromTimer:(NSTimer*)theTimer {
	NSLog(@"Timer Fired");
	[self.draggedView setHidden:YES];
	springboard = [dk_mainAppWindow hitTest:lastPoint withEvent:nil];
	[self.draggedView setHidden:NO];
	if ( springboard != nil && [springboard respondsToSelector:@selector(sendActionsForControlEvents:)] ){
		if ( theLayer ) {
			[theLayer removeAllAnimations];
		}
		theLayer = springboard.layer;

		// taken from AQGridView.
		if ([theLayer respondsToSelector: @selector(setShadowPath:)] && [theLayer respondsToSelector: @selector(shadowPath)]) {
			NSLog(@"the flash");
			CGMutablePathRef path = CGPathCreateMutable();
			CGPathAddRect( path, NULL, theLayer.bounds );
			theLayer.shadowPath = path;
			CGPathRelease( path );
			// TODO should really save all of these settings before changing them so that they can be restored later
			theLayer.shadowOffset = CGSizeZero;
			theLayer.shadowColor = [[UIColor blueColor] CGColor];
			theLayer.shadowRadius = 0.0;
			theLayer.shadowOpacity = 10.0;
			
			CABasicAnimation *animator = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
			animator.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
			animator.duration = 0.1;
			animator.fromValue = [NSNumber numberWithFloat:0.0];
			animator.toValue = [NSNumber numberWithFloat:12.0];
			animator.delegate = self;
			animator.repeatCount = 2;
			animator.autoreverses = YES;
			
			[theLayer addAnimation:animator	forKey:@"theFlash"];
		}
					
		
	}
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag {
	theLayer.shadowPath = nil;
	theLayer.shadowColor = nil;
	if ( flag ) {
		NSLog(@"send event to class: %@", NSStringFromClass([springboard class]));
		[(UIControl*)springboard sendActionsForControlEvents:(UIControlEventTouchDown | UIControlEventTouchUpInside)];
	} else {
		NSLog(@"Animation canceled");
	}
}

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender {
	// let the drag server know our frame and that we want to start dragging.
	
	CGPoint touchPoint = [sender locationInView:[self dk_mainAppWindow]];
	CGPoint viewPosition;
	CGFloat windowWidth;
	DKDropTarget *droppedTarget;
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan:
			
			// create the necessary view and animate it.
			
			self.originalView = [sender view];
			
			touchOffset = CGSizeMake(104, 39);
			
			CGPoint position = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);
			
			[self dk_displayDragViewForView:self.originalView atPoint:position];
			
			// create our drag pasteboard with the proper types.
			[self dk_createDragPasteboardForView:[sender view]];
			
			break;
		case UIGestureRecognizerStateChanged:
			
			// move the view to any point the sender is.
			// check for drop zones and light them up if necessary.
			
			windowWidth = [[self dk_mainAppWindow] frame].size.width;
			
			[self dk_messageTargetsHitByPoint:touchPoint];
			
			viewPosition = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);

			lastPoint = CGPointMake(touchPoint.x, touchPoint.y);
			
			if ( !self.pausedTimer || ![self.pausedTimer isValid] ) {
				// no timer, update point
				if ( (((lastPoint.x - pausedPoint.x) *
					   (lastPoint.x - pausedPoint.x)) + 
					  ((lastPoint.y - pausedPoint.y) *
					   (lastPoint.y - pausedPoint.y))) > 200 ) {
					// only make a new one if we moved enough
					pausedPoint = lastPoint;
					self.pausedTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(dk_springboardOpenItemFromTimer:) userInfo:nil repeats:NO];
				} else if ((((lastPoint.x - pausedPoint.x) *
								   (lastPoint.x - pausedPoint.x)) + 
								  ((lastPoint.y - pausedPoint.y) *
								   (lastPoint.y - pausedPoint.y))) > 40) {
					// moved too much, cancel the animation
					if ( theLayer ) {
						  [theLayer removeAllAnimations];
					}  
				}
			} else if ( (((lastPoint.x - pausedPoint.x) *
						  (lastPoint.x - pausedPoint.x)) + 
						 ((lastPoint.y - pausedPoint.y) *
						  (lastPoint.y - pausedPoint.y))) > 20 ) {
				// we moved too much, cancel timer
				[self.pausedTimer invalidate];
				// now make a new one
				pausedPoint = lastPoint;
				self.pausedTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(dk_springboardOpenItemFromTimer:) userInfo:nil repeats:NO];
			} 
			
			[self dk_moveDragViewToPoint:viewPosition];
			
			break;
		case UIGestureRecognizerStateRecognized:
			[self.pausedTimer invalidate];
			self.pausedTimer = nil;
			if ( theLayer ) {
				[theLayer removeAllAnimations];
			} 
			
			// the user has let go.
			droppedTarget = [self dk_dropTargetHitByPoint:touchPoint];
			
			if (droppedTarget) {
				CGPoint centerOfView = [[droppedTarget.dropView superview] convertPoint:droppedTarget.dropView.center toView:[self dk_mainAppWindow]];
				
				if ([droppedTarget.dragDelegate respondsToSelector:@selector(drag:completedOnTargetView:withDragPasteboard:context:)]) {
					
					//grab the associated objects.
					NSString *dropIdentifier = objc_getAssociatedObject([sender view], &dragKey);
					void *dropContext = objc_getAssociatedObject([sender view], &contextKey);
					
					// ask for the data and construct a UIPasteboard.
					UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:@"dragkit-drag" create:NO];
					
					NSDictionary *meta = [NSKeyedUnarchiver unarchiveObjectWithData:[dragPasteboard dataForPasteboardType:@"dragkit.metadata"]];
					NSLog(@"META: %@", meta);
					
					// get rid of our temp metadata because we're not doing interapp.
					//[dragPasteboard setData:nil forPasteboardType:@"dragkit.metadata"];
					
					[droppedTarget.dragDelegate drag:dropIdentifier completedOnTargetView:droppedTarget.dropView withDragPasteboard:dragPasteboard context:dropContext];
				}
				
				// collapse the drag view into the drop view.
				[self dk_collapseDragViewAtPoint:centerOfView];
				
				// de-highlight the view.
				[self dk_setView:droppedTarget.dropView highlighted:NO animated:YES];
				
			} else {
				[self cancelDrag];
			}
			
			break;
		case UIGestureRecognizerStateCancelled:
			[self.pausedTimer invalidate];
			self.pausedTimer = nil;
			if ( theLayer ) {
				[theLayer removeAllAnimations];
			} 
			
			// something happened and we need to cancel.
			[self cancelDrag];
			
			break;
		default:
			break;
	}
}

- (DKDropTarget *)dk_dropTargetHitByPoint:(CGPoint)point {
	for (DKDropTarget *target in dk_dropTargets) {
		if (CGRectContainsPoint(target.frameInWindow, point)) {
			return target;
		}
	}
	return nil;
}

- (void)dk_messageTargetsHitByPoint:(CGPoint)point {
	//go through the drop targets and find out of the point is in any of those rects.
	
	for (DKDropTarget *target in dk_dropTargets) {
		//convert target rect to the window's coordinates.
		if (CGRectContainsPoint(target.frameInWindow, point)) {
			//message the target.
			
			[self dk_setView:target.dropView highlighted:YES animated:YES];
			
			if (!target.containsDragView && [target.dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
				[target.dragDelegate dragDidEnterTargetView:target.dropView];
			}
			
			target.containsDragView = YES;
			
		} else if (target.containsDragView) {
			//it just left.
			
			[self dk_setView:target.dropView highlighted:NO animated:YES];
			
			if (target.containsDragView && [target.dragDelegate respondsToSelector:@selector(dragDidLeaveTargetView:)]) {
				[target.dragDelegate dragDidLeaveTargetView:target.dropView];
			}
			
			target.containsDragView = NO;
		}
	}
	
	// Try to 
	
	
}

- (void)dk_setView:(UIView *)view highlighted:(BOOL)highlighted animated:(BOOL)animated {

	CALayer *dropLayer = view.layer;
	
	if (animated) {
		[UIView beginAnimations: @"HighlightView" context: NULL];
		[UIView setAnimationCurve: UIViewAnimationCurveLinear];
		[UIView setAnimationBeginsFromCurrentState: YES];
	}
	
	// taken from AQGridView.
	if ([dropLayer respondsToSelector: @selector(setShadowPath:)] && [dropLayer respondsToSelector: @selector(shadowPath)]) {
		
		if (highlighted) {
			CGMutablePathRef path = CGPathCreateMutable();
			CGPathAddRect( path, NULL, dropLayer.bounds );
			dropLayer.shadowPath = path;
			CGPathRelease( path );
			
			dropLayer.shadowOffset = CGSizeZero;
			
			dropLayer.shadowColor = [[UIColor darkGrayColor] CGColor];
			dropLayer.shadowRadius = 12.0;
			
			dropLayer.shadowOpacity = 1.0;
			
		} else {
			dropLayer.shadowOpacity = 0.0;
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
		CGPoint translationPoint = [[self dk_mainAppWindow] convertPoint:CGPointMake(point.x + touchOffset.width, point.y + touchOffset.height)
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
		
		[[self dk_mainAppWindow] addSubview:self.draggedView];
		
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

- (void)dk_collapseDragViewAtPoint:(CGPoint)point {
	
	[UIView beginAnimations:@"DropSuck" context:NULL];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(cancelAnimationDidStop:finished:context:)];
	
	self.draggedView.transform = CGAffineTransformMakeScale(0.001, 0.001);
	self.draggedView.alpha = 0.0;
	self.draggedView.center = point;
	
	[UIView commitAnimations];
}

- (void)cancelDrag {
	// cancel the window by animating it back to its location.
	
	CGPoint originalLocation = [[self.originalView superview] convertPoint:self.originalView.center toView:[self dk_mainAppWindow]];
	
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
}

- (void)cancelAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	
	if ([animationID isEqualToString:@"SnapBack"] || [animationID isEqualToString:@"DropSuck"]) {
		
		[self.draggedView removeFromSuperview];
		self.draggedView = nil;
		
	} else if ([animationID isEqualToString:@"ResizeDragView"]) {
		[(UIView *)context removeFromSuperview];
	}
}

- (void)dealloc {
	
	[dk_applicationRegistration release];
	[dk_dropTargets release];
	[dk_mainAppWindow release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

@end
