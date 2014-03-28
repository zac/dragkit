//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

@protocol DKDragDataProvider

@optional
- (BOOL)dragShouldStartForView:(UIView *)dragView
                      position:(CGPoint)point;

- (void)dragWillStartForView:(UIView *)view position:(CGPoint)point;
- (void)dragDidStartForView:(UIView *)view position:(CGPoint)point;

- (void)dragWillFinishForView:(UIView *)view
                     position:(CGPoint)point;
- (void)dragDidFinishForView:(UIView *)view
                    position:(CGPoint)point
                   completed:(BOOL)completed;

- (id)dragMetadataForView:(UIView *)dragView
                 position:(CGPoint)point;

- (UIView *)dragPlaceholderForView:(UIView *)dragView
                          position:(CGPoint)point;

- (CGRect)dragCancelledFinalFrameForPlaceholder:(UIView *)placeholder
                                withDraggedView:(UIView *)draggedView;

@end


@protocol DKDragDelegate

@optional
- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;

- (void)dragDidUpdatePositionOverTargetView:(UIView *)targetView
                                   position:(CGPoint)point
                               withMetadata:(id)metadata;

- (void)dragCompletedOnTargetView:(UIView *)targetView
                         position:(CGPoint)point
                     withMetadata:(id)metadata;

- (CGRect)dragCompletedFinalFrameForPlaceholder:(UIView*)placeholder
                                 withTargetView:(UIView*)targetView
                                       position:(CGPoint)point;

@end

@interface DKDragDropServer : NSObject

@property (nonatomic, assign) CGAffineTransform draggingElementTransform;

- (void)enableDragging;
- (void)disableDragging;

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource;
- (void)unmarkViewAsDraggable:(UIView *)draggableView;

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;
- (void)unmarkDropTarget:(UIView *)dropView;

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer;

@end
