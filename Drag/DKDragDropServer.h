//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>

@protocol DKDragDataProvider

// request the data from the view.
- (NSData *)dataForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context;

@end

@protocol DKDragDelegate

// if any of these return YES for the type, the server does its drop drawing.
- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type;
- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withDragPasteboard:(UIPasteboard *)dragPasteboard context:(void *)context;

@end

typedef enum {
	DKDrawerVisibilityLevelHidden,
	DKDrawerVisibilityLevelPeeking,
	DKDrawerVisibilityLevelVisible,
} DKDrawerVisibilityLevel;

@class DKDrawerViewController, DKHoldingAreaViewController;

@interface DKDragDropServer : NSObject <GKSessionDelegate> {
	UIView *draggedView;
	UIView *originalView;
	
	DKDrawerViewController *drawerController;
	
	DKDrawerVisibilityLevel drawerVisibilityLevel;
	
@private
	
	// the modal view that comes up when we have a drag.
	DKHoldingAreaViewController *dk_holdingAreaViewController;
	
	// the drop targets dictionary with associated data.
	NSMutableDictionary *dk_dropTargetsDictionary;
	
	// the pointer to the main app window.
	UIWindow *dk_mainAppWindow;
	
	// the GameKit session.
	GKSession *dk_gameKitSession;
	
	// the external application registrations keyed with the peerID from GameKit.
	NSMutableDictionary *dk_externalApplications;
	
	// arrays that store the targets and delegates.
	NSMutableArray *dk_dropTargets;
}

+ (id)sharedServer;
+ (NSString *)versionString;

// application registration.
- (void)registerApplicationWithTypes:(NSArray *)types;
- (NSArray *)registeredApplications;
- (UIPasteboard *)pasteboardAddedToManifest;

- (void)cancelDrag;

@property (nonatomic, retain) UIView *draggedView;
@property (nonatomic, retain) UIView *originalView;

@property (nonatomic, retain) DKDrawerViewController *drawerController;

@property (nonatomic) DKDrawerVisibilityLevel drawerVisibilityLevel;

// the API for marking a view as draggable or a drop target.
- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource context:(void *)context;
- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;

// unmarking views
- (void)unmarkViewAsDraggable:(UIView *)draggableView;
- (void)unmarkDropTarget:(UIView *)dropView;

@end
