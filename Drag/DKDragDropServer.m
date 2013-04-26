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

static char dataProviderKey;
static char dragDelegateKey;
static char dragMetadataKey;

static char containsDragViewKey;

static DKDragDropServer *sharedInstance = nil;

@interface DKDragDropServer ()

@property (nonatomic, strong) UIView *originalView;
@property (nonatomic, strong) UIView *draggedView;
@property (nonatomic, strong) UILongPressGestureRecognizer *dragRecognizer;

@property (nonatomic, strong) UIView *lastView;
@property (nonatomic, strong) NSMutableSet *dk_dropTargets;

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
	UIView *droppedTarget = [self dk_dropTargetHitByPoint:touchPoint];
    
    UIView *dragView = [self dk_viewContainingKey:&dataProviderKey forPoint:touchPoint];
    if(dragView == nil) dragView = self.originalView;
    
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(dragView, &dataProviderKey);
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan: {
			
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
            self.draggedView.center = touchPoint;
			
			break;
        }
		case UIGestureRecognizerStateRecognized: {
			
            CGPoint positionInView = [[self dk_rootView] convertPoint:touchPoint toView:self.originalView];
            
            if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
                [dataProvider dragWillFinishForView:dragView position:positionInView];
            }
			
			if (droppedTarget && droppedTarget != self.originalView) {
								
                [self endDrag:YES];
                
                //Stop calling dragDidLeaveTargetView when changing drags (sceriu 22.03.2013)
                if(self.lastView) {
                    objc_setAssociatedObject(self.lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    self.lastView = nil;
                }
                
			} else {
				[self endDrag:NO];
			}
            
			break;
        }
		case UIGestureRecognizerStateCancelled: {

            CGPoint positionInView = [[self dk_rootView] convertPoint:touchPoint toView:self.originalView];

            if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
                [dataProvider dragWillFinishForView:self.originalView position:positionInView];
            }
            
			[self endDrag:NO];
            
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
		return;
	}
    
	NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(dropTarget, &dragDelegateKey);
	BOOL containsDragView = [(NSNumber *)objc_getAssociatedObject(dropTarget, &containsDragViewKey) boolValue];
	
    
    if (!containsDragView && [dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
        [dragDelegate dragDidEnterTargetView:dropTarget];
    }
    else if(containsDragView && [dragDelegate respondsToSelector:@selector(dragDidUpdatePositionOverTargetView:position:withObjectsDictionary:)]) {
        
        CGPoint positionInTargetView = [[self dk_rootView] convertPoint:point toView:dropTarget];
        id metadata = objc_getAssociatedObject(self.originalView, &dragMetadataKey);
        [dragDelegate dragDidUpdatePositionOverTargetView:dropTarget position:positionInTargetView withObjectsDictionary:metadata];
    }
    
    self.lastView = dropTarget;
    
    if(dropTarget) {//TODO: Rewrite this
        objc_setAssociatedObject(dropTarget, &containsDragViewKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark -
#pragma mark Drag View Creation

- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point
{
    NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(draggableView, &dataProviderKey);
    
    UIImage *backgroundImage = nil;
    
    BOOL shouldUseViewAsDragImage = NO;
    if([dataProvider respondsToSelector:@selector(dragShouldUseViewAsDragImageForView:)]) {
        shouldUseViewAsDragImage = [dataProvider dragShouldUseViewAsDragImageForView:draggableView];
    }
    
    if([dataProvider respondsToSelector:@selector(dragMetadataForView:position:)]) {
        id metadata = [dataProvider dragMetadataForView:draggableView position:point];
        objc_setAssociatedObject(draggableView, &dragMetadataKey, metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    if(shouldUseViewAsDragImage) {
        UIGraphicsBeginImageContext(draggableView.bounds.size);
        [draggableView.layer renderInContext:UIGraphicsGetCurrentContext()];
        backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    else if ([dataProvider respondsToSelector:@selector(dragImageForView:position:)]) {
        CGPoint positionInView = [[self dk_rootView] convertPoint:point toView:draggableView];
        backgroundImage = [dataProvider dragImageForView:draggableView position:positionInView];
    }
    
    UIImageView *backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
    backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
    backgroundImageView.clipsToBounds = YES;
    
    self.draggedView = [[UIView alloc] initWithFrame:backgroundImageView.bounds];
    CGPoint draggablViewCenter = [[self dk_rootView] convertPoint:draggableView.center fromView:draggableView];
    self.draggedView.center = draggablViewCenter;
    
    [self.draggedView addSubview:backgroundImageView];
    [[self dk_rootView] addSubview:self.draggedView];
    
    if (draggableView) {
        self.draggedView.alpha = 0.0f;
        
        [UIView animateWithDuration:0.25f animations:^{
            self.originalView.alpha = 0.0f;
            self.draggedView.alpha = 1.0f;
            self.draggedView.center = point;
        }];
    }
}

- (void)endDrag:(BOOL)completed
{
    UIView *draggedView = self.draggedView;
    UIView *originalView = self.originalView;
    UIView *lastView = self.lastView;
    if(!lastView) {
        lastView = originalView;
    }
    
    NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(originalView, &dataProviderKey);
    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(lastView, &dragDelegateKey);
    
    CGPoint endLocation;
    
    if(completed) {
        endLocation = [[lastView superview] convertPoint:lastView.center toView:[self dk_rootView]];
    } else {
        endLocation = [[originalView superview] convertPoint:originalView.center toView:[self dk_rootView]];
    }
    
    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        draggedView.center = endLocation;
    } completion:^(BOOL finished) {
        
        if(completed) {
            if ([dragDelegate respondsToSelector:@selector(dragCompletedOnTargetView:withObjectsDictionary:)]) {
                id metadata = objc_getAssociatedObject(originalView, &dragMetadataKey);
                [dragDelegate dragCompletedOnTargetView:lastView withObjectsDictionary:metadata];
            }
        }
        
        if([dataProvider respondsToSelector:@selector(dragDidFinishForView:position:)]) {
            [dataProvider dragDidFinishForView:originalView position:endLocation];
        }
        
        [UIView animateWithDuration:0.25f animations:^{
            draggedView.alpha = 0.25f;
            originalView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            [draggedView removeFromSuperview];
            self.draggedView = nil;
            self.originalView = nil;
        }];
    }];
}

@end
