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

@interface DKDragDropServer () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIView *originalView;
@property (nonatomic, strong) UIView *draggedView;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;

@property (nonatomic, strong) UIView *lastView;
@property (nonatomic, strong) NSMutableSet *dk_dropTargets;

@end

@implementation DKDragDropServer

- (void)dealloc
{
    [self disableDragging];
}

- (void)enabledDragging
{
    if(self.longPressGestureRecognizer == nil) {
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
        self.longPressGestureRecognizer.minimumPressDuration = 0.1f;
        self.longPressGestureRecognizer.cancelsTouchesInView = NO;
        self.longPressGestureRecognizer.delegate = self;
        
        [[self dk_rootView] addGestureRecognizer:self.longPressGestureRecognizer];
    }
}

- (void)disableDragging
{
    [self.draggedView removeFromSuperview];
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
    if(dragView == nil) {
        dragView = self.originalView;
    }
    
    CGPoint positionInView = [[self dk_rootView] convertPoint:touchPoint toView:dragView];
    
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(dragView, &dragDataProviderKey);
	
    if (!dragView) {
        [sender setState:UIGestureRecognizerStateFailed];
        return;
    }
    
    UIView *droppedTarget = [self dk_dropTargetHitByPoint:touchPoint];
    
	switch ([sender state])
    {
		case UIGestureRecognizerStateBegan: {
            BOOL shouldStartDrag = NO;
            if([dataProvider respondsToSelector:@selector(dragShouldStartForView:position:)]) {
                shouldStartDrag = [dataProvider dragShouldStartForView:dragView position:positionInView];
            }
            
            if(shouldStartDrag == NO) {
                [sender setState:UIGestureRecognizerStateFailed];
                return;
            }

			self.originalView = dragView;
			[self startDragViewForView:self.originalView atPoint:touchPoint convertedPoint:positionInView];
			break;
        }
		case UIGestureRecognizerStateChanged: {
			[self dk_messageTargetsHitByPoint:touchPoint];
            self.draggedView.center = touchPoint;
			
			break;
        }
		case UIGestureRecognizerStateRecognized: {
            BOOL completed = droppedTarget != nil;
            [self endDragForView:dragView completed:completed];
            
			break;
        }
		case UIGestureRecognizerStateCancelled: {
            if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
                [dataProvider dragWillFinishForView:self.originalView position:touchPoint];
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
	
	if ((!dropTarget && self.lastView) || (dropTarget && self.lastView && ![dropTarget isEqual:self.lastView])) {
		
		NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
		
		if ([dragDelegate respondsToSelector:@selector(dragDidLeaveTargetView:)]) {
			[dragDelegate dragDidLeaveTargetView:self.lastView];
		}
		
        objc_setAssociatedObject(self.lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.lastView = nil;
		
        if(!dropTarget && self.lastView) {
            return;
        }
	}
    
    self.lastView = dropTarget;
    
	NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
	BOOL containsDragView = [(NSNumber *)objc_getAssociatedObject(self.lastView, &containsDragViewKey) boolValue];
    
    if (!containsDragView) {
        
        if([dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
            [dragDelegate dragDidEnterTargetView:self.lastView];
        }
        
        if(self.lastView) {
            objc_setAssociatedObject(self.lastView, &containsDragViewKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    else if(containsDragView && [dragDelegate respondsToSelector:@selector(dragDidUpdatePositionOverTargetView:position:withMetadata:)]) {
        
        CGPoint positionInTargetView = [[self dk_rootView] convertPoint:point toView:self.lastView];
        id metadata = objc_getAssociatedObject(self.originalView, &dragMetadataKey);
        [dragDelegate dragDidUpdatePositionOverTargetView:self.lastView position:positionInTargetView withMetadata:metadata];
    }
}

#pragma mark -
#pragma mark Drag View Creation

- (void)startDragViewForView:(UIView *)draggableView
                     atPoint:(CGPoint)touchPoint
              convertedPoint:(CGPoint)convertedPoint
{
    NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(draggableView, &dragDataProviderKey);
 
    if([dataProvider respondsToSelector:@selector(dragWillStartForView:position:)]) {
        [dataProvider dragWillStartForView:draggableView position:convertedPoint];
    }
    
    [self dk_messageTargetsHitByPoint:touchPoint];
    
    if([dataProvider respondsToSelector:@selector(dragMetadataForView:position:)]) {
        id metadata = [dataProvider dragMetadataForView:draggableView position:convertedPoint];
        objc_setAssociatedObject(draggableView, &dragMetadataKey, metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    if([dataProvider respondsToSelector:@selector(dragPlaceholderForView:position:)]) {
        self.draggedView = [dataProvider dragPlaceholderForView:draggableView position:convertedPoint];
        
        CGRect draggedViewRect = self.draggedView.frame;
        CGPoint convertedOriginForDraggedView = [[self dk_rootView] convertPoint:self.draggedView.frame.origin fromView:draggableView];
        draggedViewRect.origin = convertedOriginForDraggedView;
        self.draggedView.frame = draggedViewRect;
    }
    
    if(self.draggedView == nil) {
        UIImage *imageRepresentationForView = [self _createImageRepresentationForView:draggableView];
        
        self.draggedView = [[UIImageView alloc] initWithImage:imageRepresentationForView];
        self.draggedView.contentMode = UIViewContentModeScaleAspectFit;
        
        CGPoint draggablViewCenter = [[self dk_rootView] convertPoint:draggableView.center fromView:draggableView];
        self.draggedView.center = draggablViewCenter;
    }
    
    [[self dk_rootView] addSubview:self.draggedView];

    self.draggedView.alpha = 0.0f;
    [UIView animateWithDuration:0.25f animations:^{
        [self.draggedView setTransform:CGAffineTransformMakeScale(1.2f, 1.2f)];
        self.draggedView.layer.masksToBounds = NO;
        self.draggedView.alpha = 1.0f;
        self.draggedView.center = touchPoint;
    } completion:^(BOOL finished) {
        if([dataProvider respondsToSelector:@selector(dragDidStartForView:position:)]) {
            [dataProvider dragDidStartForView:draggableView position:convertedPoint];
        }
    }];

}

- (void)endDragForView:(UIView *)dragView
             completed:(BOOL)completed
{
    [self.longPressGestureRecognizer setEnabled:NO];
    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
    NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(dragView, &dragDataProviderKey);
    
    CGPoint endPosition = CGPointZero;
    if(completed) {
        endPosition = [[self.lastView superview] convertPoint:self.lastView.center
                                                       toView:[self dk_rootView]];
    }
    else {
        endPosition = [[self.originalView superview] convertPoint:self.originalView.center
                                                           toView:[self dk_rootView]];
    }
    
    if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
        [dataProvider dragWillFinishForView:self.originalView position:endPosition];
    }
    
    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        [self.draggedView setTransform:CGAffineTransformIdentity];
        self.draggedView.layer.shadowPath = nil;

        if(completed) {
            if([dragDelegate respondsToSelector:@selector(dragCompletedFinalFrameForPlaceholder:withTargetView:)]) {
                self.draggedView.frame = [[self dk_rootView]
                                          convertRect:[dragDelegate dragCompletedFinalFrameForPlaceholder:self.draggedView withTargetView:self.lastView]
                                          fromView:self.lastView];
            }
        } else {
            if([dataProvider respondsToSelector:@selector(dragCancelledFinalFrameForPlaceholder:withDraggedView:)]) {
                self.draggedView.frame =[[self dk_rootView]
                                         convertRect:[dataProvider dragCancelledFinalFrameForPlaceholder:self.draggedView withDraggedView:self.originalView]
                                         fromView:self.originalView];
            }
        }
     
    } completion:^(BOOL finished) {
        
        if([dataProvider respondsToSelector:@selector(dragDidFinishForView:position:completed:)]) {
            [dataProvider dragDidFinishForView:self.originalView
                                      position:endPosition
                                     completed:completed];
        }
        
        if(completed) {
            if ([dragDelegate respondsToSelector:@selector(dragCompletedOnTargetView:position:withMetadata:)]) {
                id metadata = objc_getAssociatedObject(self.originalView, &dragMetadataKey);

                CGPoint endPointInTargetView = [self.lastView convertPoint:self.draggedView.center
                                                                  fromView:[self dk_rootView]];

                [dragDelegate dragCompletedOnTargetView:self.lastView
                                               position:endPointInTargetView
                                           withMetadata:metadata];
            }
        }
        
        [UIView animateWithDuration:0.25f animations:^{
            self.draggedView.alpha = 0.1f;
        } completion:^(BOOL finished) {
            [self.draggedView removeFromSuperview];
            self.draggedView = nil;
            self.originalView = nil;
            
            if(self.lastView) {
                objc_setAssociatedObject(self.lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            self.lastView = nil;
            
            [self.longPressGestureRecognizer setEnabled:YES];
        }];
    }];
}

#pragma mark - Helper Methods

- (UIImage *)_createImageRepresentationForView:(UIView *)view
{
    UIGraphicsBeginImageContext(view.bounds.size);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *imageRepresentationForView = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageRepresentationForView;
}


@end
