//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DKDragGestureRecognizer.h"

@protocol DKDragDataProvider

//array of types supported by view.
- (NSArray *)typesForView:(UIView *)dragView;

//request the data from the view.
- (NSData *)dataForType:(NSString *)type forView:(UIView *)dragView;

@end

@protocol DKDropDelegate

//if any of these return YES for the type, the server does its drop drawing.
- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type;
- (void)dragIsWithinTargetView:(UIView *)targetView;
- (void)dropCompletedOnTargetView:(UIView *)targetView withView:(UIView *)view;

@end

@interface DKDragDropServer : NSObject <DKDragGestureRecognizerDelegate> {
	UIView *draggedView;
	UIView *originalView;
}

+ (id)sharedServer;

- (void)cancelDrag;

@property (nonatomic, retain) UIView *draggedView;
@property (nonatomic, retain) UIView *originalView;

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dropDataSource;
/* Optional parameter for drag identification. */
- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dropDataSource;
- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDropDelegate> *)dropDelegate;

- (void)moveDragViewForView:(UIView *)draggableView toPoint:(CGPoint)point;

@end
