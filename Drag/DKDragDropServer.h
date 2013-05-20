//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@protocol DKDragDataProvider

@optional
- (BOOL)dragShouldStartForView:(UIView *)dragView
                      position:(CGPoint)point;

- (id)dragMetadataForView:(UIView *)dragView
                 position:(CGPoint)point;

- (UIView *)dragPlaceholderForView:(UIView *)dragView
                          position:(CGPoint)point;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@protocol DKDragDelegate

@optional

- (void)dragWillStartForView:(UIView *)view position:(CGPoint)point;
- (void)dragDidStartForView:(UIView *)view position:(CGPoint)point;

- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;

- (void)dragDidUpdatePositionOverTargetView:(UIView *)targetView position:(CGPoint)point withMetadata:(id)metadata;

- (void)dragWillFinishForView:(UIView *)view position:(CGPoint)point;
- (void)dragDidFinishForView:(UIView *)view position:(CGPoint)point completed:(BOOL)completed;

- (void)dragCompletedOnTargetView:(UIView *)targetView withMetadata:(id)metadata;

- (BOOL)dragShouldSnapToCenterOfTargetOnCompletion;

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
extern NSString *const DKPasteboardNameDrag;

@class DKApplicationRegistration;
@interface DKDragDropServer : NSObject <UIGestureRecognizerDelegate>

- (void)enabledDragging;
- (void)disableDragging;

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource;
- (void)unmarkViewAsDraggable:(UIView *)draggableView;

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;
- (void)unmarkDropTarget:(UIView *)dropView;

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer;

@end
