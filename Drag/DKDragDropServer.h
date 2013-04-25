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

- (void)drag:(NSString *)dragID willStartForView:(UIView *)view position:(CGPoint)point;
- (void)drag:(NSString *)dragID didStartForView:(UIView *)view position:(CGPoint)point; // (modification by dmakarenko 14.01.2013)

- (void)drag:(NSString *)dragID willFinishForView:(UIView *)view position:(CGPoint)point;
- (void)drag:(NSString *)dragID didFinishForView:(UIView *)view position:(CGPoint)point; // review name later (modification by pdcgomes 06.09.2012, modification by dmakarenko 14.01.2013)

- (BOOL)shouldStartDrag:(NSString *)dragID forView:(UIView *)dragView position:(CGPoint)point context:(void *)context; // (modification by dmakarenko 14.01.2013)

- (BOOL)drag:(NSString*)dropID shouldUseViewAsDragImageForView:(UIView*)dragView;

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

@private
	
	// UI for the holding area.
	UIView *dk_holdingArea;
	
	NSArray *dk_currentDragTypes;
	
	// arrays that store the targets and delegates.
	NSMutableArray *dk_dropTargets;
	
    // Point of initial touch.
	CGPoint initialTouchPoint;

	// point to determine how much it has moved
	CGPoint lastPoint;
	
	UIImage *background;
    
    UILongPressGestureRecognizer *dragRecognizer;
}

+ (id)sharedServer;

// application registration.
- (void)registerApplicationWithTypes:(NSArray *)types;

- (void)cancelDrag;

@property (nonatomic, retain) UIView *draggedView;
@property (nonatomic, retain) UIView *originalView;

// the API for marking a view as draggable or a drop target.
- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource context:(void *)context;
- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate;

// unmarking views
- (void)unmarkViewAsDraggable:(UIView *)draggableView;
- (void)unmarkDropTarget:(UIView *)dropView;


- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer;

@end
