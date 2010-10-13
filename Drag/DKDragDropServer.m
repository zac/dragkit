//
//  DKDragServer.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//
//  Singleton code stolen from: http://boredzo.org/blog/archives/2009-06-17/doing-it-wrong

#import "DKDragDropServer.h"
#import <MobileCoreServices/UTType.h>

#import "DKApplicationRegistration.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#import <objc/runtime.h>

static DKDragDropServer *sharedInstance = nil;

// constants
NSString *const DKPasteboardNameDrag = @"dragkit-drag";

@interface DKDragDropServer (DKPrivate)

- (void)dk_clearDragPasteboard;
- (void)dk_showHoldingAreaForPasteboard:(UIPasteboard *)pasteboard;
- (void)dk_hideHoldingArea;
- (BOOL)dk_dragPasteboard:(UIPasteboard *)pasteboard conformsToTypes:(NSArray *)types;
- (void)dk_handleLongPress:(UIGestureRecognizer *)sender;
- (UIImage *)dk_generateImageFromView:(UIView *)theView;
- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point;
- (void)dk_moveDragViewToPoint:(CGPoint)point;
- (void)dk_createDragPasteboardForView:(UIView *)view;
- (void)dk_messageTargetsHitByPoint:(CGPoint)point;
- (void)dk_setView:(UIView *)view highlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)dk_handleURL:(NSNotification *)notification;
- (UIWindow *)dk_mainAppWindow;
- (UIView *)dk_viewContainingKey:(void *)key forPoint:(CGPoint)point;
- (UIView *)dk_dragViewUnderPoint:(CGPoint)point;
- (UIView *)dk_dropTargetHitByPoint:(CGPoint)point;
- (void)dk_collapseDragView;

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
			
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(dk_applicationDidBecomeActive:)
														 name:UIApplicationDidBecomeActiveNotification
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

- (void)dk_applicationDidBecomeActive:(NSNotification *)notification {
	NSLog(@"window: %@", [self dk_mainAppWindow]);
	
	UILongPressGestureRecognizer *dragRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
	dragRecognizer.minimumPressDuration = 0.1;
	dragRecognizer.numberOfTapsRequired = 1;
	
	[[self dk_mainAppWindow] addGestureRecognizer:dragRecognizer];
	[dragRecognizer release];
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
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:NO];
	if (dragPasteboard) dragPasteboard.persistent = YES;
}

#define MAX_NUMBER_OF_REGISTERED_APPS 100

- (BOOL)dk_dragPasteboard:(UIPasteboard *)pasteboard conformsToTypes:(NSArray *)types {
	for (NSString *type in types) {
		// check to see if any of the types being dragged are ones we support.
		
		for (NSArray *dragTypes in [pasteboard pasteboardTypesForItemSet:nil]) {
			
			// ignore if we are dealing with the metadata.
			if ([dragTypes containsObject:@"dragkit.metadata"]) continue;
			
			for (NSArray *individualType in dragTypes) {
				if (UTTypeConformsTo((CFStringRef)type, (CFStringRef)individualType)) {
					return YES;
				}
			}
		}
	}
	
	return NO;
}

- (void)registerApplicationWithTypes:(NSArray *)types {
	
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
	NSDictionary *meta = [NSKeyedUnarchiver unarchiveObjectWithData:[[dragPasteboard valuesForPasteboardType:@"dragkit.metadata" inItemSet:nil] lastObject]];
	
	if (meta) {
		// we have a drag in progress.
		
		if ([self dk_dragPasteboard:dragPasteboard conformsToTypes:types]) {
			// create and show the holding area.
			[self dk_showHoldingAreaForPasteboard:dragPasteboard];
		}
	}
	
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
	
	// use associated objects to attach our drag identifier.
	objc_setAssociatedObject(draggableView, &dragKey, dragID, OBJC_ASSOCIATION_COPY_NONATOMIC);
	
	// use associated objects to attach our context.
	objc_setAssociatedObject(draggableView, &contextKey, context, OBJC_ASSOCIATION_ASSIGN);
	
	// attach the drag delegate.
	objc_setAssociatedObject(draggableView, &dataProviderKey, dragDataSource, OBJC_ASSOCIATION_ASSIGN);
}

static char acceptedTypesKey;
static char dragDelegateKey;
static char containsDragViewKey;

- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate {
	
	objc_setAssociatedObject(dropView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	// use associated objects to attach our supported types.
	objc_setAssociatedObject(dropView, &acceptedTypesKey, types, OBJC_ASSOCIATION_COPY_NONATOMIC);
	
	// use associated objects to attach our delegate.
	objc_setAssociatedObject(dropView, &dragDelegateKey, dropDelegate, OBJC_ASSOCIATION_ASSIGN);
	
	[dk_dropTargets addObject:dropView];
}

- (void)unmarkViewAsDraggable:(UIView *)draggableView {
	// clear our associated objects.
	objc_setAssociatedObject(draggableView, &dragKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(draggableView, &contextKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(draggableView, &dataProviderKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (void)unmarkDropTarget:(UIView *)dropView {
	
	// clear our associated objects.
	objc_setAssociatedObject(dropView, &acceptedTypesKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(dropView, &dragDelegateKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(dropView, &containsDragViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[dk_dropTargets removeObject:dropView];
}

- (void)dk_createDragPasteboardForView:(UIView *)view {
	//grab the associated objects.
	NSString *dropIdentifier = objc_getAssociatedObject(view, &dragKey);
	void *dropContext = objc_getAssociatedObject(view, &contextKey);
	NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
	
	
	// if we are the data provider, that means we already have a pasteboard.
	if (dataProvider == self) {
		// set up our current drag types.
		
		UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
		[dk_currentDragTypes release];
		
		dk_currentDragTypes = [[NSArray alloc] initWithArray:[[dragPasteboard pasteboardTypesForItemSet:nil] lastObject]];
		
		return;
	}
	
	// clear the drag pasteboard.
	[self dk_clearDragPasteboard];
	
	// ask for the data and construct a UIPasteboard.
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
	dragPasteboard.persistent = YES;
	
	// associate metadata with the pasteboard.
	NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
	
	// add the drag image. if none is set, we can use default.
	[metadata setObject:UIImagePNGRepresentation(background) forKey:@"dragImage"];

	// add the registration for the application that we're dragging from.
	[metadata setObject:dk_applicationRegistration forKey:@"draggingApplication"];
	
	// set our metadata on our private metadata type.
	[dragPasteboard addItems:[NSArray arrayWithObject:[NSDictionary dictionaryWithObject:[NSKeyedArchiver archivedDataWithRootObject:metadata]
																				  forKey:@"dragkit.metadata"]]];
	[metadata release];
	
	// go through each type supported by the drop target
	// and request the data for that type from the data source.
	
	NSArray *advertisedTypes = [dataProvider typesSupportedForDrag:dropIdentifier forView:view context:dropContext];
	NSLog(@"advertisedTypes: %@", advertisedTypes);
	NSMutableArray *pasteboardTypes = [NSMutableArray array];
	NSMutableArray *justTypes = [NSMutableArray array];
	for (NSString *type in advertisedTypes) {
		NSData *data = [dataProvider dataForType:type withDrag:dropIdentifier forView:view context:dropContext];
		
		if (data) {
			[justTypes addObject:type];
			[pasteboardTypes addObject:[NSDictionary dictionaryWithObject:data forKey:type]];
		}
	}
	
	[dk_currentDragTypes release];
	dk_currentDragTypes = [[NSArray alloc] initWithArray:justTypes];
	
	[dragPasteboard addItems:pasteboardTypes];
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

CGPoint lastTouch;

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender {
	// let the drag server know our frame and that we want to start dragging.
	
	CGPoint touchPoint = [sender locationInView:[self dk_mainAppWindow]];
	CGPoint viewPosition;
	CGFloat windowWidth;
	UIView *droppedTarget;
	UIView *dragView;
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan:
			
			// create the necessary view and animate it.
			[self dk_hideHoldingArea];
			
			dragView = [self dk_dragViewUnderPoint:touchPoint];
			
			if (!dragView) {
				[sender setState:UIGestureRecognizerStateFailed];
				return;
			}
			
			self.originalView = dragView;
			
			// our touch offset is just 0,0, which makes it the center.
			touchOffset = CGSizeMake(0,70);
			
			CGPoint position = CGPointMake(touchPoint.x - touchOffset.width, touchPoint.y - touchOffset.height);
			
			[self dk_displayDragViewForView:self.originalView atPoint:position];
			
			// create our drag pasteboard with the proper types.
			[self dk_createDragPasteboardForView:dragView];
			
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
			
			droppedTarget = [self dk_dropTargetHitByPoint:lastPoint];
			
			NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(droppedTarget, &dragDelegateKey);
			
			if (droppedTarget) {
				
				if ([dragDelegate respondsToSelector:@selector(drag:completedOnTargetView:withDragPasteboard:context:)]) {
					
					//grab the associated objects.
					NSString *dropIdentifier = objc_getAssociatedObject(droppedTarget, &dragKey);
					void *dropContext = objc_getAssociatedObject(droppedTarget, &contextKey);
					
					// ask for the data and construct a UIPasteboard.
					UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:NO];
					
					[dragDelegate drag:dropIdentifier completedOnTargetView:droppedTarget withDragPasteboard:dragPasteboard context:dropContext];
					
					[dragPasteboard setItems:nil];
				}
				
				// collapse the drag view into the drop view.
				[self dk_collapseDragView];
				
				// de-highlight the view.
				[self dk_setView:droppedTarget highlighted:NO animated:YES];
				
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
	
	lastTouch = [sender locationInView:[self dk_mainAppWindow]];
}

- (UIView *)dk_viewContainingKey:(void *)key forPoint:(CGPoint)point {
	
	UIView *currentView = [[self dk_mainAppWindow] hitTest:point withEvent:nil];
	
	id obj = nil;
	
	while (currentView) {
		obj = objc_getAssociatedObject(currentView, key);
		
		if (obj) return currentView;
		currentView = [currentView superview];
	}
	
	return nil;
}

- (UIView *)dk_dragViewUnderPoint:(CGPoint)point {
	return [self dk_viewContainingKey:&dataProviderKey forPoint:point];
}

- (UIView *)dk_dropTargetHitByPoint:(CGPoint)point {
	
	for (UIView *dropTarget in dk_dropTargets) {
		CGRect frameInWindow = [[dropTarget superview] convertRect:dropTarget.frame toView:[self dk_mainAppWindow]];
		if (CGRectContainsPoint(frameInWindow, point)) {
			NSArray *acceptedTypes = objc_getAssociatedObject(dropTarget, &acceptedTypesKey);
			if ([[NSSet setWithArray:acceptedTypes] intersectsSet:[NSSet setWithArray:dk_currentDragTypes]]) {
				return dropTarget;
			}
		}
	}
	
	return nil;
}

UIView *lastView = nil;
- (void)dk_messageTargetsHitByPoint:(CGPoint)point {
	//go through the drop targets and find out of the point is in any of those rects.
	
	UIView *dropTarget = [self dk_dropTargetHitByPoint:point];
	
	if (!dropTarget && lastView) {
		
		objc_setAssociatedObject(lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		
		NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(lastView, &dragDelegateKey);
		
		if ([dragDelegate respondsToSelector:@selector(dragDidLeaveTargetView:)]) {
			[dragDelegate dragDidLeaveTargetView:dropTarget];
		}
		
		[self dk_setView:lastView highlighted:NO animated:YES];
		
		[lastView release];
		lastView = nil;
		
		return;
	}
	
	NSArray *acceptedTypes = objc_getAssociatedObject(dropTarget, &acceptedTypesKey);
	NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(dropTarget, &dragDelegateKey);
	BOOL containsDragView = [(NSNumber *)objc_getAssociatedObject(dropTarget, &containsDragViewKey) boolValue];
	
	if ([[NSSet setWithArray:acceptedTypes] intersectsSet:[NSSet setWithArray:dk_currentDragTypes]]) {
		
		[self dk_setView:dropTarget highlighted:YES animated:YES];
		
		if (!containsDragView && [dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
			[dragDelegate dragDidEnterTargetView:dropTarget];
		}
		
		lastView = [dropTarget retain];
		
		objc_setAssociatedObject(dropTarget, &containsDragViewKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
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

- (UIImage *)dk_generateImageFromView:(UIView *)theView {
	
	if (!theView) return nil;
	
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
		
		// transition from the dragImage to our view.
		NSString *dropIdentifier = objc_getAssociatedObject(draggableView, &dragKey);
		void *dropContext = objc_getAssociatedObject(draggableView, &contextKey);
		NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(draggableView, &dataProviderKey);
		
		UIImage *overlay = [UIImage imageNamed:@"drag_overlay.png"];
		background = nil;
		if ([dataProvider respondsToSelector:@selector(imageForDrag:forView:context:)]) {
			background = [dataProvider imageForDrag:dropIdentifier forView:draggableView context:dropContext];
		} else {
			
			UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
			
			NSDictionary *metadata = [NSKeyedUnarchiver unarchiveObjectWithData:[[dragPasteboard valuesForPasteboardType:@"dragkit.metadata" inItemSet:nil] lastObject]];
			
			NSData *imageData = [metadata objectForKey:@"dragImage"];
			
			if (imageData) {
				background = [UIImage imageWithData:imageData];
			}
			
			if (!imageData || !background) {
				background = [UIImage imageNamed:@"drag_default.png"];
			}
		}
		
		// create our drag view where we want it.
		self.draggedView = [[[UIView alloc] initWithFrame:CGRectMake((int)(point.x - overlay.size.width / 2.0),
																	 (int)(point.y - overlay.size.height / 2.0),
																	 overlay.size.width,
																	 overlay.size.height)] autorelease];
		
		UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 4, 108, 108)];
		backgroundImageView.image = background;
		backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
		backgroundImageView.layer.cornerRadius = 10;
		backgroundImageView.clipsToBounds = YES;
		
		UIImageView *dragImageView = [[UIImageView alloc] initWithFrame:self.draggedView.bounds];
		dragImageView.image = overlay;
		
		[self.draggedView addSubview:backgroundImageView];
		[self.draggedView addSubview:dragImageView];
		
		[backgroundImageView release];
		[dragImageView release];
		
		[[self dk_mainAppWindow] addSubview:self.draggedView];
		
		if (draggableView) {
			
			self.draggedView.transform = CGAffineTransformMakeTranslation(touchOffset.width, touchOffset.height);
			self.draggedView.transform = CGAffineTransformScale(self.draggedView.transform, 0.001, 0.001);
			self.draggedView.alpha = 0.0;
			
			[UIView beginAnimations:@"DragExpand" context:NULL];
			[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
			[UIView setAnimationDuration:.3];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(cancelAnimationDidStop:finished:context:)];
			
			self.draggedView.transform = CGAffineTransformIdentity;
			self.draggedView.alpha = 1.0;
			
			[UIView commitAnimations];
		}
	}
}

- (void)dk_moveDragViewToPoint:(CGPoint)point {
	
	if (!self.draggedView) {
		NSLog(@"ERROR: No drag view.");
		return;
	}
	
	self.draggedView.frame = CGRectMake((int)(point.x - self.draggedView.frame.size.width / 2.0),
										(int)(point.y - self.draggedView.frame.size.height / 2.0),
										self.draggedView.frame.size.width,
										self.draggedView.frame.size.height);
}

- (void)dk_collapseDragView {
	
	[UIView beginAnimations:@"DropSuck" context:NULL];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(cancelAnimationDidStop:finished:context:)];
	
	self.draggedView.transform = CGAffineTransformMakeScale(0.001, 0.001);
	self.draggedView.alpha = 0.0;
	self.draggedView.center = CGPointMake(self.draggedView.center.x + touchOffset.width, self.draggedView.center.y + touchOffset.height);
	
	[UIView commitAnimations];
}

- (void)dk_clearDragPasteboard {
	
	[dk_currentDragTypes release];
	dk_currentDragTypes = nil;
	
	UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
	pasteboard.persistent = NO;
	[pasteboard setItems:nil];
}

- (void)cancelDrag {
	// cancel the window by animating it back to its location.
	
	[self dk_clearDragPasteboard];
	
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
		
	}
}

#pragma mark -
#pragma mark Holding Area Drawing

- (void)dk_showHoldingAreaForPasteboard:(UIPasteboard *)pasteboard {
	
	UIWindow *mainWindow = [self dk_mainAppWindow];
	
	dk_holdingArea = [[UIView alloc] initWithFrame:mainWindow.bounds];
	dk_holdingArea.backgroundColor = [UIColor blackColor];
	dk_holdingArea.alpha = 0.0;
	
	[mainWindow addSubview:dk_holdingArea];
	
	[self dk_displayDragViewForView:nil atPoint:CGPointMake(mainWindow.frame.size.width / 2.0, mainWindow.frame.size.height / 2.0)];
	self.draggedView.alpha = 0.0;
	
	// use associated objects to attach our drag identifier.
	objc_setAssociatedObject(self.draggedView, &dragKey, @"DragKit-Internal", OBJC_ASSOCIATION_COPY_NONATOMIC);
	// attach the drag delegate.
	objc_setAssociatedObject(self.draggedView, &dataProviderKey, self, OBJC_ASSOCIATION_ASSIGN);
	
	UIPanGestureRecognizer *dragGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
	[self.draggedView addGestureRecognizer:dragGesture];
	[dragGesture release];
	
	[UIView beginAnimations:@"HoldingAreaShow" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:0.3];
	
	dk_holdingArea.alpha = 0.4;
	self.draggedView.alpha = 1.0;
	
	[UIView commitAnimations];
}

- (void)dk_hideHoldingArea {
	[UIView beginAnimations:@"HoldingAreaHide" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(hideAnimationDidStop:finished:context:)];
	
	dk_holdingArea.alpha = 0.0;
	
	[UIView commitAnimations];
}

- (void)hideAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[dk_holdingArea removeFromSuperview];
}

- (void)dealloc {
	
	[dk_applicationRegistration release];
	[dk_dropTargets release];
	[dk_mainAppWindow release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

@end
