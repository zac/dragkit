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

- (id)init
{
    if(self = [super init]) {
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
        self.longPressGestureRecognizer.minimumPressDuration = 0.1f;
        self.longPressGestureRecognizer.cancelsTouchesInView = NO;
        self.longPressGestureRecognizer.delegate = self;
        self.longPressGestureRecognizer.enabled = NO;
        _draggingElementTransform = CGAffineTransformMakeScale(1.2f, 1.2f);
        [[self dk_rootView] addGestureRecognizer:self.longPressGestureRecognizer];
    }
    
    return self;
}

- (void)enableDragging
{
    [self.longPressGestureRecognizer setEnabled:YES];
}

- (void)disableDragging
{
    [self.draggedView removeFromSuperview];
    [self.longPressGestureRecognizer setEnabled:NO];
}

- (UIView *)dk_rootView
{
    NSArray *windows = [[UIApplication sharedApplication] windows];
    if ([windows count]) {
        return [windows[0] valueForKeyPath:@"rootViewController.view"];
    }
    
    return nil;
}

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer *)gestureRecognizer
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

- (void)updateOriginalView:(UIView *)originalView {
    self.originalView = originalView;
}

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
    UIView *retView = nil;
    
	for (UIView *dropTarget in self.dk_dropTargets) {
		CGRect frameInRootView = [[dropTarget superview] convertRect:dropTarget.frame toView:[self dk_rootView]];
		if (CGRectContainsPoint(frameInRootView, point)) {
            if (retView) {
                retView = [self _frontViewBetweenView:retView andView:dropTarget];
            } else {
                retView = dropTarget;
            }
        }
    }
	
	return retView;
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
        if([dragDelegate respondsToSelector:@selector(dragDidUpdatePositionOverTargetView:position:withMetadata:)]) {
            CGPoint positionInTargetView = [[self dk_rootView] convertPoint:point toView:self.lastView];
            id metadata = objc_getAssociatedObject(self.originalView, &dragMetadataKey);
            [dragDelegate dragDidUpdatePositionOverTargetView:self.lastView position:positionInTargetView withMetadata:metadata];            
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
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.25f animations:^{
        [weakSelf.draggedView setTransform:_draggingElementTransform];
        weakSelf.draggedView.layer.masksToBounds = NO;
        weakSelf.draggedView.alpha = 1.0f;
        weakSelf.draggedView.center = touchPoint;
    } completion:nil];
    
    if([dataProvider respondsToSelector:@selector(dragDidStartForView:position:)]) {
        [dataProvider dragDidStartForView:draggableView position:convertedPoint];
    }

    [self dk_messageTargetsHitByPoint:touchPoint];
}

- (void)endDragForView:(UIView *)dragView
             completed:(BOOL)completed
{
    [self.longPressGestureRecognizer setEnabled:NO];
    NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(self.lastView, &dragDelegateKey);
    NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(self.originalView, &dragDataProviderKey);
    
    CGPoint endPosition = CGPointZero;
    if(completed) {
        endPosition = [self.lastView convertPoint:self.draggedView.center
                                         fromView:[self dk_rootView]];
    }
    else {
        endPosition = [self.originalView convertPoint:self.draggedView.center
                                             fromView:[self dk_rootView]];
    }
    
    if([dataProvider respondsToSelector:@selector(dragWillFinishForView:position:)]) {
        [dataProvider dragWillFinishForView:self.originalView position:endPosition];
    }
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        [weakSelf.draggedView setTransform:CGAffineTransformIdentity];
        weakSelf.draggedView.layer.shadowPath = nil;
        
        if(completed) {
            if([dragDelegate respondsToSelector:@selector(dragCompletedFinalFrameForPlaceholder:withTargetView:position:)]) {
                weakSelf.draggedView.frame = [[weakSelf dk_rootView]
                                              convertRect:[dragDelegate dragCompletedFinalFrameForPlaceholder:weakSelf.draggedView withTargetView:weakSelf.lastView position:endPosition]
                                              fromView:weakSelf.lastView];
            }
        } else {
            if([dataProvider respondsToSelector:@selector(dragCancelledFinalFrameForPlaceholder:withDraggedView:)]) {
                weakSelf.draggedView.frame =[[self dk_rootView]
                                             convertRect:[dataProvider dragCancelledFinalFrameForPlaceholder:weakSelf.draggedView withDraggedView:weakSelf.originalView]
                                             fromView:weakSelf.originalView];
            }
        }
        
    } completion:^(BOOL finished) {
        
        if([dataProvider respondsToSelector:@selector(dragDidFinishForView:position:completed:)]) {
            [dataProvider dragDidFinishForView:weakSelf.originalView
                                      position:endPosition
                                     completed:completed];
        }
        
        if(completed) {
            if ([dragDelegate respondsToSelector:@selector(dragCompletedOnTargetView:position:withMetadata:)]) {
                id metadata = objc_getAssociatedObject(weakSelf.originalView, &dragMetadataKey);
                
                CGPoint endPointInTargetView = [weakSelf.lastView convertPoint:weakSelf.draggedView.center
                                                                      fromView:[weakSelf dk_rootView]];
                
                [dragDelegate dragCompletedOnTargetView:self.lastView
                                               position:endPointInTargetView
                                           withMetadata:metadata];
            }
        }
        
        [UIView animateWithDuration:0.25f animations:^{
            weakSelf.draggedView.alpha = 0.1f;
        } completion:^(BOOL finished) {
            [weakSelf.draggedView removeFromSuperview];
            weakSelf.draggedView = nil;
            weakSelf.originalView = nil;
            
            if(weakSelf.lastView) {
                objc_setAssociatedObject(weakSelf.lastView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            weakSelf.lastView = nil;
            
            [weakSelf.longPressGestureRecognizer setEnabled:YES];
        }];
    }];
}

#pragma mark - Helper Methods

- (NSArray *)_getAncestorTreeForView:(UIView *)view
{
    NSMutableArray *retArray = [NSMutableArray array];
    
    BOOL finishCondition = NO;
    
    UIView *currentSuperView = nil;
    UIView *currentView = view;
    [retArray addObject:currentView];
    while (NO == finishCondition) {
        currentSuperView = currentView.superview;
        [retArray addObject:currentSuperView];
        currentView = currentSuperView;
        if ([currentSuperView isKindOfClass:[UIWindow class]]) {
            finishCondition = YES;
        }
    }
    return retArray;
}

- (UIView *)_frontViewBetweenView:(UIView *)view1 andView:(UIView *)view2
{
    NSArray *view1Tree = [self _getAncestorTreeForView:view1];
    NSArray *view2Tree = [self _getAncestorTreeForView:view2];
    
    NSPredicate *relativeComplementPredicate =
    [NSPredicate predicateWithFormat:@"SELF IN %@", view2Tree];
    NSArray *relativeComplement =
    [view1Tree filteredArrayUsingPredicate:relativeComplementPredicate];
    
    UIView *commonAncestor = relativeComplement[0];
    NSInteger indexOfCommonAncestorView1Tree = [view1Tree indexOfObject:commonAncestor];
    NSInteger indexOfCommonAncestorView2Tree = [view2Tree indexOfObject:commonAncestor];

    //if the index is zero it means that the commonAncestor is view1 or view2

    if (0 == indexOfCommonAncestorView1Tree) {
        return view2;
    } else if (0 == indexOfCommonAncestorView2Tree) {
        return view1;
    }

    NSInteger indexOfView1 = [commonAncestor.subviews indexOfObject:view1Tree[indexOfCommonAncestorView1Tree - 1]];
    NSInteger indexOfView2 = [commonAncestor.subviews indexOfObject:view2Tree[indexOfCommonAncestorView2Tree - 1]];
    
    if (indexOfView1 > indexOfView2) {
        return view1;
    }
    return view2;
}

- (UIImage *)_createImageRepresentationForView:(UIView *)view
{
    UIGraphicsBeginImageContext(view.bounds.size);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *imageRepresentationForView = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageRepresentationForView;
}


@end
