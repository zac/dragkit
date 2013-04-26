//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

@protocol DKDragDataProvider

- (id)objectForView:(UIView *)dragView position:(CGPoint)point;

- (UIImage *)dragImageForView:(UIView *)dragView position:(CGPoint)point;

- (void)dragWillStartForView:(UIView *)view position:(CGPoint)point;
- (void)dragDidStartForView:(UIView *)view position:(CGPoint)point;

- (void)dragWillFinishForView:(UIView *)view position:(CGPoint)point;
- (void)dragDidFinishForView:(UIView *)view position:(CGPoint)point;

- (BOOL)dragShouldStartForView:(UIView *)dragView position:(CGPoint)point;

- (BOOL)dragShouldUseViewAsDragImageForView:(UIView*)dragView;

@end

@protocol DKDragDelegate

- (void)dragDidEnterTargetView:(UIView *)targetView;

- (void)dragDidLeaveTargetView:(UIView *)targetView;

- (void)dragDidUpdatePositionOverTargetView:(UIView *)targetView position:(CGPoint)point withObjectsDictionary:(NSDictionary*)objectsDictionary;

- (void)dragCompletedOnTargetView:(UIView *)targetView withObjectsDictionary:(NSDictionary *)objectsDictionary;

- (void)dragDidChangeTargetView:(UIView *)targetView;

@end

@class DKApplicationRegistration;

extern NSString *const DKPasteboardNameDrag;

@interface DKDragDropServer : NSObject <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readonly) UIView *originalView;

+ (id)sharedServer;

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource;
- (void)unmarkViewAsDraggable:(UIView *)draggableView;

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;
- (void)unmarkDropTarget:(UIView *)dropView;

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer;

@end
