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

- (NSArray *)typesSupportedForDrag:(NSString *)dragID forView:(UIView *)dragView;

@optional

- (NSData *)dataForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point;
- (id)objectForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point;

- (UIImage *)imageForDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point;

- (void)drag:(NSString *)dragID willStartForView:(UIView *)view position:(CGPoint)point;
- (void)drag:(NSString *)dragID didStartForView:(UIView *)view position:(CGPoint)point;

- (void)drag:(NSString *)dragID willFinishForView:(UIView *)view position:(CGPoint)point;
- (void)drag:(NSString *)dragID didFinishForView:(UIView *)view position:(CGPoint)point;

- (BOOL)shouldStartDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point;

- (BOOL)drag:(NSString*)dropID shouldUseViewAsDragImageForView:(UIView*)dragView;

@end

@protocol DKDragDelegate

// if any of these return YES for the type, the server does its drop drawing.
- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type;
- (void)dragDidEnterTargetView:(UIView *)targetView;
- (void)dragDidLeaveTargetView:(UIView *)targetView;
- (void)dragDidUpdatePositionOverTargetView:(UIView *)targetView position:(CGPoint)point withObjectsDictionary:(NSDictionary*)objectsDictionary;
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withObjectsDictionary:(NSDictionary *)objectsDictionary;
@optional
- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withDragPasteboard:(UIPasteboard *)dragPasteboard;
- (void)dragDidChangeTargetView:(UIView *)targetView;

@end

@class DKApplicationRegistration;

extern NSString *const DKPasteboardNameDrag;

@interface DKDragDropServer : NSObject <UIGestureRecognizerDelegate>

@property (nonatomic, strong, readonly) UIView *originalView;

+ (id)sharedServer;

- (void)cancelDrag;

- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource;
- (void)unmarkViewAsDraggable:(UIView *)draggableView;

- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;
- (void)unmarkDropTarget:(UIView *)dropView;

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer;

@end
