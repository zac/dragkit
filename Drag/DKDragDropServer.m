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

static char dragDataProviderKey;
static char dragDelegateKey;
static char dragMetadataKey;

static char containsDragViewKey;

@interface DKDragDropServer ()

@property (nonatomic, strong) UIView *originalView;
@property (nonatomic, strong) UIView *draggedView;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;

@property (nonatomic, strong) UIView *lastView;
@property (nonatomic, strong) NSMutableSet *dk_dropTargets;

@end

@implementation DKDragDropServer

- (void)enabledDragging
{
    if(self.longPressGestureRecognizer == nil) {
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
        self.longPressGestureRecognizer.minimumPressDuration = 0.25f;
        self.longPressGestureRecognizer.delegate = self;
        
        [[self dk_rootView] addGestureRecognizer:self.longPressGestureRecognizer];
    }
}

- (void)disableDragging
{
    [[self dk_rootView] removeGestureRecognizer:self.longPressGestureRecognizer];
    self.longPressGestureRecognizer = nil;
}

- (UIView *)dk_rootView
{
	return [UIApplication sharedApplication].keyWindow.rootViewController.view;
}

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer
{
    [self.longPressGestureRecognizer requireGestureRecognizerToFail:gestureRecognizer];
}

#pragma mark -
#pragma mark Marking Views

- (void)markViewAsDraggable:(UIView *)draggableView withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource
{
	objc_setAssociatedObject(draggableView, &dragDataProviderKey, dragDataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (void)markViewAsDropTarget:(UIView *)dropView withDelegate:(NSObject <DKDragDelegate> *)dropDelegate
{
	objc_setAssociatedObject(dropView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(dropView, &dragDelegateKey, dropDelegate, OBJC_ASSOCIATION_ASSIGN);
	
    if(self.dk_dropTargets == nil) {
        self.dk_dropTargets = [[NSMutableSet alloc] init];
    }
    
	[self.dk_dropTargets addObject:dropView];
}

- (void)unmarkViewAsDraggable:(UIView *)draggableView
{
	objc_setAssociatedObject(draggableView, &dragDataProviderKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (void)unmarkDropTarget:(UIView *)dropView
{
	objc_setAssociatedObject(dropView, &dragDelegateKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(dropView, &containsDragViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self.dk_dropTargets removeObject:dropView];
}

#pragma mark -
#pragma mark Dragging Callback

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender
{    
	CGPoint touchPoint = [sender locationInView:[self dk_rootView]];
	
    UIView *dragView = [self dk_viewContainingKey:&dragDataProviderKey forPoint:touchPoint];
    if(dragView == nil) dragView = self.originalView;
    
    CGPoint positionInView = [[self dk_rootView] convertPoint:touchPoint toView:dragView];
    
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(dragView, &dragDataProviderKey);
    id<DKDragDelegate, NSObject> dragDelegate = objc_getAssociatedObject(dragView, &dragDelegateKey);
	
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
    
    UIView *droppedTarget = [self dk_dropTargetHitByPoint:touchPoint];
    
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan:
        {
			self.originalView = dragView;
			[self startDragViewForView:self.originalView atPoint:touchPoint];
			break;
        }
		case UIGestureRecognizerStateChanged:
        {
			[self dk_messageTargetsHitByPoint:touchPoint];
            self.draggedView.center = touchPoint;
			
			break;
        }
		case UIGestureRecognizerStateRecognized:
        {
            BOOL completed = droppedTarget && droppedTarget != self.originalView;
            [self endDragForView:dragView completed:completed];
            
			break;
        }
		case UIGestureRecognizerStateCancelled:
        {
            if([dragDelegate respondsToSelector:@selector(dragWillFinishForView:position:)]) {
                [dragDelegate dragWillFinishForView:self.originalView position:positionInView];
            }
            
			[self endDragForView:dragView completed:NO];
            
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
		
		return;
	}
    
	NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(dropTarget, &dragDelegateKey);
	BOOL containsDragView = [(NSNumber *)objc_getAssociatedObject(dropTarget, &containsDragViewKey) boolValue];
	
    
    if (!containsDragView && [dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
        [dragDelegate dragDidEnterTargetView:dropTarget];
    }
    else if(containsDragView && [dragDelegate respondsToSelector:@selector(dragDidUpdatePositionOverTargetView:position:withMetadata:)]) {
        
        CGPoint positionInTargetView = [[self dk_rootView] convertPoint:point toView:dropTarget];
        id metadata = objc_getAssociatedObject(self.originalView, &dragMetadataKey);
        [dragDelegate dragDidUpdatePositionOverTargetView:dropTarget position:positionInTargetView withMetadata:metadata];
    }
    
    self.lastView = dropTarget;
    
    if(dropTarget) {//TODO: Rewrite this
        objc_setAssociatedObject(dropTarget, &containsDragViewKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark -
#pragma mark Drag View Creation

- (void)startDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point
{
    NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(draggableView, &dragDataProviderKey);
    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(draggableView, &dragDelegateKey);
 
    if([dragDelegate respondsToSelector:@selector(dragWillStartForView:position:)]) {
        [dragDelegate dragWillStartForView:draggableView position:point];
    }
    
    if([dataProvider respondsToSelector:@selector(dragMetadataForView:position:)]) {
        id metadata = [dataProvider dragMetadataForView:draggableView position:point];
        objc_setAssociatedObject(draggableView, &dragMetadataKey, metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    if([dataProvider respondsToSelector:@selector(dragPlaceholderForView:position:)]) {
        self.draggedView = [dataProvider dragPlaceholderForView:draggableView position:point];
    }
    
    if(self.draggedView == nil) {
        UIGraphicsBeginImageContext(draggableView.bounds.size);
        [draggableView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *placeholderImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        self.draggedView = [[UIImageView alloc] initWithImage:placeholderImage];
        self.draggedView.contentMode = UIViewContentModeScaleAspectFit;
    }

    CGPoint draggablViewCenter = [[self dk_rootView] convertPoint:draggableView.center fromView:draggableView];
    self.draggedView.center = draggablViewCenter;
    
    [[self dk_rootView] addSubview:self.draggedView];
    

    self.draggedView.alpha = 0.0f;
    [UIView animateWithDuration:0.25f animations:^{
        [self.draggedView setTransform:CGAffineTransformMakeScale(1.2f, 1.2f)];
        
        self.draggedView.layer.masksToBounds = NO;
        self.draggedView.layer.cornerRadius = 8;
        self.draggedView.layer.shadowOffset = CGSizeMake(0, 2);
        self.draggedView.layer.shadowRadius = 4;
        self.draggedView.layer.shadowOpacity = 0.2;
        
        self.draggedView.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.draggedView.bounds].CGPath;
        
        [self.originalView setAlpha:0.0f];
        self.draggedView.alpha = 1.0f;
        self.draggedView.center = point;
    } completion:^(BOOL finished) {
        if([dragDelegate respondsToSelector:@selector(dragDidStartForView:position:)]) {
            [dragDelegate dragDidStartForView:draggableView position:point];
        }
    }];

}

- (void)endDragForView:(UIView*)dragView completed:(BOOL)completed
{
    [self.longPressGestureRecognizer setEnabled:NO];
    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(dragView, &dragDelegateKey);
    
    CGPoint endPosition;
    if(completed) {
        endPosition = [[self.lastView superview] convertPoint:self.lastView.center toView:[self dk_rootView]];
    } else {
        endPosition = [[self.originalView superview] convertPoint:self.originalView.center toView:[self dk_rootView]];
    }
    
    if([dragDelegate respondsToSelector:@selector(dragWillFinishForView:position:)]) {
        [dragDelegate dragWillFinishForView:self.originalView position:endPosition];
    }
    
    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        
        [self.draggedView setTransform:CGAffineTransformIdentity];

        self.draggedView.layer.shadowPath = nil;
        self.draggedView.center = endPosition;
        
    } completion:^(BOOL finished) {

        [self.originalView setAlpha:1.0f];
        
        if([dragDelegate respondsToSelector:@selector(dragDidFinishForView:position:completed:)]) {
            [dragDelegate dragDidFinishForView:self.originalView position:endPosition completed:completed];
        }
        
        if(completed) {
            if ([dragDelegate respondsToSelector:@selector(dragCompletedOnTargetView:withMetadata:)]) {
                id metadata = objc_getAssociatedObject(self.originalView, &dragMetadataKey);
                [dragDelegate dragCompletedOnTargetView:self.lastView withMetadata:metadata];
            }
        }
        
        [UIView animateWithDuration:0.25f animations:^{
            self.draggedView.alpha = 0.1f;
        } completion:^(BOOL finished) {
            [self.draggedView removeFromSuperview];
            self.draggedView = nil;
            self.originalView = nil;
            self.lastView = nil;
            
            [self.longPressGestureRecognizer setEnabled:YES];
        }];
    }];
}

@end
