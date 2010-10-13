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

// request the data from the view.

- (NSArray *)typesSupportedForDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context;
- (NSData *)dataForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context;

@optional
- (UIImage *)imageForDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context;

@end

@protocol DKDragDelegate

// if any of these return YES for the type, the server does its drop drawing.
- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type;
- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withDragPasteboard:(UIPasteboard *)dragPasteboard context:(void *)context;

@end

@class DKApplicationRegistration;

extern NSString *const DKPasteboardNameDrag;

@interface DKDragDropServer : NSObject {
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
	
	// point to determine how much it has moved
	CGPoint lastPoint;
	CGPoint pausedPoint;
	
	// time at point
	NSTimer *pausedTimer;
	
	BOOL inOnePlace;
	
	UIView *springboard;
	
	CALayer *theLayer;
	
	UIImage *background;
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

@end
