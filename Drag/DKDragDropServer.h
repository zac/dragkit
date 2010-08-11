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

//array of types supported by view.
- (NSArray *)typesForView:(UIView *)dragView;

//request the data from the view.
- (NSData *)dataForType:(NSString *)type forView:(UIView *)dragView;

@end

@protocol DKDragDelegate

//if any of these return YES for the type, the server does its drop drawing.
- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type;
- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView context:(void *)context;

@end

typedef enum {
	DKDrawerVisibilityLevelHidden,
	DKDrawerVisibilityLevelPeeking,
	DKDrawerVisibilityLevelVisible,
} DKDrawerVisibilityLevel;

@class DKDrawerViewController;

@interface DKDragDropServer : NSObject <GKSessionDelegate> {
	UIView *draggedView;
	UIView *originalView;
	
	DKDrawerViewController *drawerController;
	
	DKDrawerVisibilityLevel drawerVisibilityLevel;
	
@private
	
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

//application registration.
- (void)registerApplicationWithTypes:(NSArray *)types;
- (NSArray *)registeredApplications;
- (UIPasteboard *)pasteboardAddedToManifest;

- (void)cancelDrag;

@property (nonatomic, retain) UIView *draggedView;
@property (nonatomic, retain) UIView *originalView;

@property (nonatomic, retain) DKDrawerViewController *drawerController;

@property (nonatomic) DKDrawerVisibilityLevel drawerVisibilityLevel;

//- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dropDataSource context:(void *)context;
/* Optional parameter for drag identification. */
- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dropDataSource context:(void *)context;
- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;


@end
