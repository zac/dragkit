//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAAnimation.h>

@protocol DKDragDataProvider

- (NSArray *)typesSupportedForDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context;

@optional

- (NSData *)dataForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point context:(void *)context; // (modification by dmakarenko 14.01.2013)
- (id)objectForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point context:(void *)context; // (modification by dmakarenko 14.01.2013)

- (UIImage *)imageForDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point context:(void *)context; // (modification by dmakarenko 14.01.2013)
- (void)drag:(NSString *)dragID didStartForView:(UIView *)view position:(CGPoint)point; // (modification by dmakarenko 14.01.2013)
- (void)drag:(NSString *)dragID didFinishForView:(UIView *)view position:(CGPoint)point; // review name later (modification by pdcgomes 06.09.2012, modification by dmakarenko 14.01.2013)
- (BOOL)shouldStartDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point context:(void *)context; // (modification by dmakarenko 14.01.2013)

// TODO -- add support for custom animations (pdcgomes 10.09.2012)
//- (void)performDragAnimationForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context;

@end

@protocol DKDragDelegate

// if any of these return YES for the type, the server does its drop drawing.
- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type;
- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;
- (void)dragDidUpdatePositionOverTargetView:(UIView *)targetView position:(CGPoint)point withObjectsDictionary:(NSDictionary*)objectsDictionary; // (modification by sceriu 01.02.2013
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withObjectsDictionary:(NSDictionary *)objectsDictionary context:(void *)context;  // (modification by dmakarenko 25.01.2013)
@optional
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withDragPasteboard:(UIPasteboard *)dragPasteboard context:(void *)context;
- (void)dragDidChangeTargetView:(UIView *)targetView;

@end

@class DKApplicationRegistration;

extern NSString *const DKPasteboardNameDrag;

@interface DKDragDropServer : NSObject <UIGestureRecognizerDelegate> {
	UIView *draggedView;
	UIView *originalView;

@private
	
	// UI for the holding area.
	UIView *dk_holdingArea;
	UILabel *dk_holdingAreaLabel;
	
	NSArray *dk_currentDragTypes;
	
	// the drop targets dictionary with associated data.
	NSMutableDictionary *dk_dropTargetsDictionary;
	
	// the pointer to the main app window.
	UIWindow *dk_mainAppWindow;
	
	// the manifest of all apps on the system that support DragKit.
	NSMutableArray *dk_manifest;
	
	// the resolved supported applications.
	NSMutableArray *dk_supportedApplications;
	
	// the application registrations.
	DKApplicationRegistration *dk_applicationRegistration;
	
	// arrays that store the targets and delegates.
	NSMutableArray *dk_dropTargets;
	
    // Point of initial touch.
	CGPoint initialTouchPoint;

	// point to determine how much it has moved
	CGPoint lastPoint;
	CGPoint pausedPoint;
	
	// time at point
	NSTimer *pausedTimer;
	
	BOOL inOnePlace;
	
	UIView *springboard;
	
	CALayer *theLayer;
	
	UIImage *background;
    
    UILongPressGestureRecognizer *dragRecognizer;
}

+ (id)sharedServer;
+ (NSString *)versionString;

// application registration.
- (void)registerApplicationWithTypes:(NSArray *)types;
- (NSArray *)registeredApplications;

- (void)cancelDrag;

@property (nonatomic, retain) UIView *draggedView;
@property (nonatomic, retain) UIView *originalView;
@property (nonatomic, retain) NSTimer *pausedTimer;

- (void)resetRegistrationDatabase;

// the API for marking a view as draggable or a drop target.
- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource context:(void *)context;
- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;

// unmarking views
- (void)unmarkViewAsDraggable:(UIView *)draggableView;
- (void)unmarkDropTarget:(UIView *)dropView;


- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag;

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer;

@end
