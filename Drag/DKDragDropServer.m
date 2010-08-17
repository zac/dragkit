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

#import "DKDrawerViewController.h"

#import "DKApplicationRegistration.h"
#import "DKExternalApplicationRegistration.h"

#import <QuartzCore/QuartzCore.h>

#import <objc/runtime.h>

static DKDragDropServer *sharedInstance = nil;

@interface DKDragDropServer (DKPrivate)

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender;
- (UIImage *)dk_generateImageForDragFromView:(UIView *)theView;
- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point;
- (void)dk_moveDragViewToPoint:(CGPoint)point;
- (void)dk_messageTargetsHitByPoint:(CGPoint)point;
- (void)dk_setView:(UIView *)view highlighted:(BOOL)highlighted animated:(BOOL)animated;
- (void)dk_handleURL:(NSNotification *)notification;
- (UIWindow *)dk_mainAppWindow;
- (DKDropTarget *)dk_dropTargetHitByPoint:(CGPoint)point;
- (void)dk_collapseDragViewAtPoint:(CGPoint)point;

// GameKit

// GameKit data handling.
- (void)receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context;

@end

@implementation DKDragDropServer

@synthesize draggedView, originalView, drawerController, drawerVisibilityLevel;

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
													 selector:@selector(dk_handleURL:)
														 name:UIApplicationDidFinishLaunchingNotification
													   object:nil];
			
			dk_externalApplications = [[NSMutableDictionary alloc] init];
			
			NSString *deviceName = [[UIDevice currentDevice] name];
			NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
			dk_gameKitSession = [[GKSession alloc] initWithSessionID:@"DragKitSession"
														 displayName:[NSString stringWithFormat:@"%@ (%@)", deviceName, appName]
														 sessionMode:GKSessionModePeer];
			dk_gameKitSession.delegate = self;
			[dk_gameKitSession setDataReceiveHandler:self withContext:nil];
			
			//start advertising immediately.
			dk_gameKitSession.available = YES;
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

- (void)registerApplicationWithTypes:(NSArray *)types {
	
	UIPasteboard *registrationPasteboard = [self pasteboardAddedToManifest];
	
	NSLog(@"registration: %@", [registrationPasteboard name]);
	
	DKApplicationRegistration *appRegistration = [DKApplicationRegistration registrationWithDragTypes:types];
	
	NSData *registrationData = [NSKeyedArchiver archivedDataWithRootObject:appRegistration];
	
	[registrationPasteboard setData:registrationData forPasteboardType:@"dragkit.registration"];
}

- (NSArray *)registeredApplications {
	//returns all registered applications.
	
	if (dk_supportedApplications) return [[dk_supportedApplications retain] autorelease];
	
	UIPasteboard *manifestPasteboard = [UIPasteboard pasteboardWithName:@"dragkit-manifest" create:YES];
	NSData *manifestData = [manifestPasteboard dataForPasteboardType:@"dragkit.manifest"];
	
	NSAssert(manifestData, @"Expected a DragKit manifest to already be created.");
	
	NSMutableArray *manifest = [NSKeyedUnarchiver unarchiveObjectWithData:manifestData];
	
	dk_supportedApplications = [[NSMutableArray alloc] init];
	NSMutableArray *appsToDelete = [NSMutableArray array];
	for (NSString *pasteboardName in manifest) {
		
		if ([pasteboardName isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"dragkit-pasteboard"]]) {
			continue;
		}
		
		UIPasteboard *registrationPasteboard = [UIPasteboard pasteboardWithName:pasteboardName create:YES];
		
		NSData *pasteboardData = [registrationPasteboard dataForPasteboardType:@"dragkit.registration"];
		
		if (pasteboardData) {
			DKApplicationRegistration *appRegistration = [NSKeyedUnarchiver unarchiveObjectWithData:pasteboardData];
			[dk_supportedApplications addObject:appRegistration];
		} else {
			// we don't have a registered pasteboard.
			// the app must have been deleted.
			[appsToDelete addObject:pasteboardName];
		}
	}
	
	[manifest removeObjectsInArray:appsToDelete];
	
	if ([appsToDelete count]) {
		// set the modified manifest.
		[manifestPasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:manifest] forPasteboardType:@"dragkit.manifest"];
	}
	
	NSLog(@"registered apps: %@", dk_supportedApplications);
	
	return [[dk_supportedApplications retain] autorelease];
}

#define MAX_NUMBER_OF_REGISTERED_APPS 100

- (void)resetRegistrationDatabase {
	[UIPasteboard removePasteboardWithName:@"dragkit-manifest"];
	
	for (int i = 0; i < MAX_NUMBER_OF_REGISTERED_APPS; i++) {
		[UIPasteboard removePasteboardWithName:[NSString stringWithFormat:@"dragkit-application:%d", i]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"dragkit-pasteboard"];
}

// this is where the horrible, horrible magic happens.
- (UIPasteboard *)pasteboardAddedToManifest {
	
	UIPasteboard *pasteboard = nil;
	
	// check to see if we've already created a pasteboard. this returns a valid pasteboard in the common case.
	NSString *pasteboardName = [[NSUserDefaults standardUserDefaults] objectForKey:@"dragkit-pasteboard"];
	
	if (pasteboardName) {
		pasteboard = [UIPasteboard pasteboardWithName:pasteboardName create:YES];
		pasteboard.persistent = YES;
		
		NSData *registrationData = [pasteboard dataForPasteboardType:@"dragkit.registration"];
		if (!registrationData) {
			NSLog(@"ERROR: The pasteboard our app said it created is now gone.");
			[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"dragkit-pasteboard"];
			pasteboardName = nil;
			pasteboard = nil;
		}
	}
	
	// check to see if the manifest has been created yet.
	UIPasteboard *manifestPasteboard = [UIPasteboard pasteboardWithName:@"dragkit-manifest" create:YES];
	NSData *manifestData = [manifestPasteboard dataForPasteboardType:@"dragkit.manifest"];
	
	// we found the manifest and we are already in it.
	if (pasteboard && manifestData) return pasteboard;
	
	// we need to create the manifest or our pasteboard or both.
	
	NSMutableArray *manifest = [NSMutableArray array];
	
	// the original application that created the manifest could have been deleted.
	// this would leave UIPasteboards out there without a central manifest.
	// we must scan through the possible application registration slots and recreate the manifest.
	// of course, we could be the first app. In that case, we'll scan through and just create the manifest
	// pointing to just our app's registration data.
	
	NSString *firstAvailableSlot = nil;
	
	NSLog(@"Our manifest was deleted. Recreating...");
	for (int i = 0; i < MAX_NUMBER_OF_REGISTERED_APPS; i++) {
		UIPasteboard *possibleApp = [UIPasteboard pasteboardWithName:[NSString stringWithFormat:@"dragkit-application:%d", i] create:YES];
		if ([possibleApp containsPasteboardTypes:[NSArray arrayWithObject:@"dragkit.registration"]]) {
			
			// if it is our pasteboard, don't bother.
			// pasteboardName could be nil if we haven't been launched.
			// in that case, we'll get a manifest that's missing us anyway.
			if ([possibleApp.name isEqualToString:pasteboardName]) continue;
			
			[manifest addObject:possibleApp.name];
			
		} else if (!firstAvailableSlot) {
			firstAvailableSlot = [possibleApp.name retain];
		}
	}
	
	// we should always have a first available slot.
	// if we don't, we've run out of slots and probably should have picked a higher number than 100.
	if (firstAvailableSlot) {
		if (pasteboard) {
			// we already have a pasteboard. add its name to the manifest and return.
			// this is the case where we've launched but the app that last created our manifest was deleted. poor app.
			[manifest addObject:pasteboardName];
		} else {
			
			// create a new pasteboard with the name firstAvailableSlot.
			pasteboard = [UIPasteboard pasteboardWithName:firstAvailableSlot create:YES];
			pasteboard.persistent = YES;
			
			[[NSUserDefaults standardUserDefaults] setObject:firstAvailableSlot forKey:@"dragkit-pasteboard"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			
			[manifest addObject:firstAvailableSlot];
		}
	} else {
		NSLog(@"ERROR: All available app registration slots are used.");
		return nil;
	}
	
	if ([manifest count]) {
		NSLog(@"creating manifest: %@", manifest);
		
		NSData *newManifestData = [NSKeyedArchiver archivedDataWithRootObject:manifest];
		
		NSAssert(manifestPasteboard, @"ERROR: We don't have a valid pasteboard.");
		[manifestPasteboard setData:newManifestData forPasteboardType:@"dragkit.manifest"];
	}
	
	return pasteboard;
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

#pragma mark -
#pragma mark Dragging Callback

#define MARGIN_Y (50)

#define PEEK_DISTANCE (30)
#define VISIBLE_WIDTH (300)

CGSize touchOffset;

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
			
			self.drawerVisibilityLevel = DKDrawerVisibilityLevelPeeking;
			
			break;
		case UIGestureRecognizerStateChanged:
			
			// move the view to any point the sender is.
			// check for drop zones and light them up if necessary.
			
			windowWidth = [[self dk_mainAppWindow] frame].size.width;
			
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
			droppedTarget = [self dk_dropTargetHitByPoint:touchPoint];
			
			if (droppedTarget) {
				CGPoint centerOfView = [[droppedTarget.dropView superview] convertPoint:droppedTarget.dropView.center toView:[self dk_mainAppWindow]];
				
				if ([droppedTarget.dragDelegate respondsToSelector:@selector(drag:completedOnTargetView:withDragPasteboard:context:)]) {
					
					//grab the associated objects.
					NSString *dropIdentifier = objc_getAssociatedObject([sender view], &dragKey);
					void *dropContext = objc_getAssociatedObject([sender view], &contextKey);
					NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject([sender view], &dataProviderKey);
					
					// ask for the data and construct a UIPasteboard.
					UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithUniqueName];
					
					// go through each type supported by the drop target
					// and request the data for that type from the data source.
					for (NSString *type in droppedTarget.acceptedTypes) {
						NSData *data = [dataProvider dataForType:type withDrag:dropIdentifier forView:[sender view] context:dropContext];
						
						if (data) [dragPasteboard setData:data forPasteboardType:type];
					}
					
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
	
	CGRect windowFrame = [[self dk_mainAppWindow] frame];
	
	if (!self.drawerController) {
		self.drawerController = [[[DKDrawerViewController alloc] init] autorelease];
		self.drawerController.view.frame = CGRectMake(windowFrame.size.width,
													  MARGIN_Y,
													  VISIBLE_WIDTH,
													  windowFrame.size.height - 2 * MARGIN_Y);
		[[self dk_mainAppWindow] addSubview:self.drawerController.view];
		
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

#pragma mark -
#pragma mark GameKit Session Delegate

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state {
	// update the state of the item in the drawer to reflect the new state.
	NSLog(@"peer: %@ didChangeState: %d", peerID, state);
	
	if (state == GKPeerStateAvailable) {
		
		DKExternalApplicationRegistration *externalApp = [dk_externalApplications objectForKey:peerID];
		
		if (!externalApp) {
			// create the application and insert it into our dictionary.
			externalApp = [[DKExternalApplicationRegistration alloc] init];
			externalApp.peerID = peerID;
			
			// the state is idle for now until we get more registration information.
			externalApp.currentState = DKExternalApplicaionStateUnregistered;
			
			NSLog(@"display: %@", [dk_gameKitSession displayNameForPeer:peerID]);
		}
	} else if (state == GKPeerStateConnected) {
		// send something!
	} else if (state == GKPeerStateUnavailable) {
		
		NSLog(@"Device became unavailable: %@", peerID);
		
		// the device became unavailable.
		[[dk_externalApplications objectForKey:peerID] setCurrentState:DKExternalApplicaionStateDisconnected];
		[dk_externalApplications removeObjectForKey:peerID];
	}
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID {
	// a peer wants to connect.
	
	NSLog(@"peer: %@ wants to connect");
	
	NSError *error = nil;
	BOOL connectionAccepted = [session acceptConnectionFromPeer:peerID error:&error];
	
	if (!connectionAccepted) {
		//could not accept connection.
		NSLog(@"Could not accept connection: %@", error);
	}
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error {
	// some error occurred while trying to connect to peer.
	NSLog(@"Couldn't connect with peer %@: %@", peerID, error);
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error {
	NSLog(@"Session failed: %@", error);
}


- (void)receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context {
	//got data!
	NSLog(@"peer %@ gave data: %@", peer, data);
}

#pragma mark -
#pragma mark URL Open Handlers

// DragKit URLs look like so: x-drag-com.zacwhite.appname://?dkpasteboard=23402349343&type=image.png

- (void)dk_handleURL:(NSNotification *)notification {
	//handle the URL!
	NSLog(@"notification: %@", notification);
	
//	UIAlertView *options = [[UIAlertView alloc] initWithTitle:@"options" message:[NSString stringWithFormat:@"%@", launchOptions] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
//	[options show];
//	[options release];
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
	
	self.drawerVisibilityLevel = DKDrawerVisibilityLevelHidden;
}

- (void)cancelAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	
	if ([animationID isEqualToString:@"SnapBack"] || [animationID isEqualToString:@"DropSuck"]) {
		[self.draggedView removeFromSuperview];
		self.draggedView = nil;
		
		self.drawerVisibilityLevel = DKDrawerVisibilityLevelHidden;
		
	} else if ([animationID isEqualToString:@"ResizeDragView"]) {
		[(UIView *)context removeFromSuperview];
	}
}

- (void)dealloc {
	
	[dk_dropTargets release];
	[dk_mainAppWindow release];
	
	[dk_externalApplications release];
	[dk_gameKitSession release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

@end
