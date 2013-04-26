//
//  DKDragServer.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDragDropServer.h"

#import <objc/runtime.h>
#import <QuartzCore/CALayer.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

static char dragKey;
static char dataProviderKey;
static char dragDelegateKey;
static char containsDragViewKey;

static DKDragDropServer *sharedInstance = nil;

@interface DKDragDropServer ()

@property (nonatomic, strong) UIView *originalView;
@property (nonatomic, strong) UIView *draggedView;
@property (nonatomic, strong) UILongPressGestureRecognizer *dragRecognizer;

@property (nonatomic, strong) UIView *lastView;
@property (nonatomic, assign) BOOL targetIsChanged;
@property (nonatomic, assign) BOOL targetIsOriginalView;
@property (nonatomic, strong) NSMutableSet *dk_dropTargets;

@property (nonatomic, assign) CGPoint initialTouchPoint;
@property (nonatomic, assign) CGPoint lastPoint;

@property (nonatomic, strong) UIImage *background;

@end

@implementation DKDragDropServer

+ (id)sharedServer
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
	return sharedInstance;
}

- (UIView *)dk_rootView
{
	return [UIApplication sharedApplication].keyWindow.rootViewController.view;
}

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer
{
    [self.dragRecognizer requireGestureRecognizerToFail:gestureRecognizer];
}

#pragma mark -
#pragma mark Marking Views

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource
{
	objc_setAssociatedObject(draggableView, &dataProviderKey, dragDataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDragDelegate> *)dropDelegate
{
	objc_setAssociatedObject(dropView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(dropView, &dragDelegateKey, dropDelegate, OBJC_ASSOCIATION_ASSIGN);
	
    if(self.dk_dropTargets == nil) {
        self.dk_dropTargets = [[NSMutableSet alloc] init];
    }
    
	[self.dk_dropTargets addObject:dropView];
    
    if(self.dragRecognizer == nil) {
        self.dragRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
        self.dragRecognizer.minimumPressDuration = 0.25f;
        self.dragRecognizer.delegate = self;
        
        [[self dk_rootView] addGestureRecognizer:self.dragRecognizer];
    }
}

- (void)unmarkViewAsDraggable:(UIView *)draggableView
{
	objc_setAssociatedObject(draggableView, &dragKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(draggableView, &dataProviderKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (void)unmarkDropTarget:(UIView *)dropView
{
	objc_setAssociatedObject(dropView, &dragDelegateKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(dropView, &containsDragViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self.dk_dropTargets removeObject:dropView];
    
    if(![self.dk_dropTargets count]) {
        [[self dk_rootView] removeGestureRecognizer:self.dragRecognizer];
        self.dragRecognizer = nil;
    }
}

#pragma mark -
#pragma mark Dragging Callback

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender
{    
	CGPoint touchPoint = [sender locationInView:[self dk_rootView]];
	UIView *droppedTarget = [self dk_dropTargetHitByPoint:self.lastPoint];
    
    UIView *dragView = [self dk_viewContainingKey:&dataProviderKey forPoint:touchPoint];
    
    if(dragView == nil) dragView = self.originalView;
    
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(dragView, &dataProviderKey);
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan: {
			
            self.initialTouchPoint = touchPoint;

            CGPoint positionInView = [[self dk_rootView] convertPoint:touchPoint toView:dragView];
			
			if (!dragView) {
				[sender setState:UIGestureRecognizerStateFailed];
				return;
			}
            
            BOOL shouldStartDrag = NO;
            if([dataProvider respondsToSelector:@selector(dragShouldStartForView:position:)]) {
                shouldStartDrag = [dataProvider dragShouldStartForView:dragView position:positionInView];
            }
            
			if(shouldStartDrag == NO) {
                [sender setState:UIGestureRecognizerStateFailed];
                return;
            }
            
			self.originalView = dragView;
            
            
            if([dataProvider respondsToSelector:@selector(dragWillStartForView:position:)]) {
                [dataProvider dragWillStartForView:dragView position:positionInView];
            }
            
            
			[self dk_displayDragViewForView:self.originalView atPoint:touchPoint];
			
            
            
            if([dataProvider respondsToSelector:@selector(dragDidStartForView:position:)]) {
                [dataProvider dragDidStartForView:dragView position:positionInView];
            }
            
			break;
        }
		case UIGestureRecognizerStateChanged: {

			[self dk_messageTargetsHitByPoint:touchPoint];
			self.lastPoint = CGPointMake(touchPoint.x, touchPoint.y);
            self.draggedView.center = touchPoint;
			
			break;
        }
		case UIGestureRecognizerStateRecognized: {
			
            CGPoint positionInView = [[self dk_rootView] convertPoint:self.initialTouchPoint toView:self.originalView];
            
            if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
                [dataProvider dragWillFinishForView:dragView position:positionInView];
            }
			
			NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(droppedTarget, &dragDelegateKey);
			
			if (droppedTarget) {
								
				if ([dragDelegate respondsToSelector:@selector(dragCompletedOnTargetView:withObjectsDictionary:)]) {
					
					[dragDelegate dragCompletedOnTargetView:droppedTarget withObjectsDictionary:nil];//TODO: fix this
				}

				// collapse the drag view into the drop view.
                [UIView animateWithDuration:0.25f animations:^{
                    self.draggedView.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [self.draggedView removeFromSuperview];
                    self.draggedView = nil;
                }];    
                
                //Stop calling dragDidLeaveTargetView when changing drags (sceriu 22.03.2013)
                if(self.lastView) {
                    objc_setAssociatedObject(self.lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    self.lastView = nil;
                }
                
			} else {
				[self cancelDrag];
			}
            self.targetIsOriginalView = NO;
            self.targetIsChanged = NO;
            
            
            if([dataProvider respondsToSelector:@selector(dragDidFinishForView:position:)]) {
                [dataProvider dragDidFinishForView:dragView position:positionInView];
            }
            
            self.originalView = nil;
			
			break;
        }
		case UIGestureRecognizerStateCancelled: {

            CGPoint positionInView = [[self dk_rootView] convertPoint:self.initialTouchPoint toView:self.originalView];

            if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
                [dataProvider dragWillFinishForView:self.originalView position:positionInView];
            }
            
			[self cancelDrag];
            
            
            if([dataProvider respondsToSelector:@selector(dragDidFinishForView:position:)]) {
                [dataProvider dragDidFinishForView:dragView position:positionInView];
            }
            self.originalView = nil;
			
			break;
        }
		default:
			break;
	}
}

- (UIView *)dk_viewContainingKey:(void *)key forPoint:(CGPoint)point
{
	
	UIView *currentView = [[self dk_rootView] hitTest:point withEvent:nil];
	
	id obj = nil;
	
	while (currentView) {
		obj = objc_getAssociatedObject(currentView, key);
		
		if (obj) return currentView;
		currentView = [currentView superview];
	}
	
	return nil;
}

- (UIView *)dk_dropTargetHitByPoint:(CGPoint)point
{
	for (UIView *dropTarget in self.dk_dropTargets) {
		CGRect frameInRootView = [[dropTarget superview] convertRect:dropTarget.frame toView:[self dk_rootView]];
		if (CGRectContainsPoint(frameInRootView, point)) {
            return dropTarget;
        }
    }
	
	return nil;
}

- (void)dk_messageTargetsHitByPoint:(CGPoint)point
{
	UIView *dropTarget = [self dk_dropTargetHitByPoint:point];
	
	if (!dropTarget && self.lastView) {
		
		objc_setAssociatedObject(self.lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		
		NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
		
		if ([dragDelegate respondsToSelector:@selector(dragDidLeaveTargetView:)]) {
			[dragDelegate dragDidLeaveTargetView:dropTarget];
		}
		
		
		self.lastView = nil;
        self.targetIsChanged = NO;
        self.targetIsOriginalView = NO;
		return;
	} else {
        if (dropTarget) {
            if ([dropTarget isEqual:self.lastView]) {
                if (NO == self.targetIsOriginalView) {
                    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
                    if ([dragDelegate respondsToSelector:@selector(dragDidChangeTargetView:)]) {
                        [dragDelegate dragDidChangeTargetView:dropTarget];
                    }
                    self.targetIsOriginalView = YES;
                }
                
            } else {
                if (self.targetIsOriginalView) {
                    self.targetIsOriginalView = NO;
                    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
                    if ([dragDelegate respondsToSelector:@selector(dragDidChangeTargetView:)]) {
                        [dragDelegate dragDidChangeTargetView:dropTarget];
                    }
                }
            }
        } else {
            self.targetIsChanged = NO;
            self.targetIsOriginalView = NO;
        }
    }
    
	NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(dropTarget, &dragDelegateKey);
	BOOL containsDragView = [(NSNumber *)objc_getAssociatedObject(dropTarget, &containsDragViewKey) boolValue];
	
    
    if (!containsDragView && [dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
        [dragDelegate dragDidEnterTargetView:dropTarget];
    }
    else if(containsDragView && [dragDelegate respondsToSelector:@selector(dragDidUpdatePositionOverTargetView:position:withObjectsDictionary:)]) {
        
        CGPoint positionInTargetView = [[self dk_rootView] convertPoint:point toView:dropTarget];
        [dragDelegate dragDidUpdatePositionOverTargetView:dropTarget position:positionInTargetView withObjectsDictionary:nil];//TODO:FIX THIS
    }
    
    self.lastView = dropTarget;
    
    if(dropTarget) {
        objc_setAssociatedObject(dropTarget, &containsDragViewKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark -
#pragma mark Drag View Creation

- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point
{
	if (!self.draggedView) {
		
		// transition from the dragImage to our view.
		NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(draggableView, &dataProviderKey);
		
		self.background = nil;
		
        BOOL shouldUseViewAsDragImage = NO;
        if([dataProvider respondsToSelector:@selector(dragShouldUseViewAsDragImageForView:)])
            shouldUseViewAsDragImage = [dataProvider dragShouldUseViewAsDragImageForView:draggableView];

        if(shouldUseViewAsDragImage) {
            UIGraphicsBeginImageContext(draggableView.bounds.size);
            [draggableView.layer renderInContext:UIGraphicsGetCurrentContext()];
            self.background = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        else if ([dataProvider respondsToSelector:@selector(dragImageForView:position:)]) {
            CGPoint positionInView = [[self dk_rootView] convertPoint:point toView:draggableView];
            self.background = [dataProvider dragImageForView:draggableView position:positionInView];
        }
        
        UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:self.background];
		backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
		backgroundImageView.clipsToBounds = YES;
		
		// create our drag view where we want it.
		self.draggedView = [[UIView alloc] initWithFrame:backgroundImageView.bounds];
        self.draggedView.center = point;
		
		[self.draggedView addSubview:backgroundImageView]; 
		[[self dk_rootView] addSubview:self.draggedView];
		
		if (draggableView) {
			self.draggedView.alpha = 0.0;
            
            [UIView animateWithDuration:0.25f animations:^{
                self.draggedView.alpha = 1.0f;
            }];
        }
	}
}

- (void)cancelDrag
{
	CGPoint originalLocation = [[self.originalView superview] convertPoint:self.originalView.center toView:[self dk_rootView]];
    
    [UIView animateWithDuration:0.25f animations:^{
        self.draggedView.center = originalLocation;
        self.draggedView.alpha = 0.5;
    } completion:^(BOOL finished) {
        [self.draggedView removeFromSuperview];
		self.draggedView = nil;
    }];
}

@end
