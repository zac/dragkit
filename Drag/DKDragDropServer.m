//
//  DKDragServer.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//
//  Singleton code stolen from: http://boredzo.org/blog/archives/2009-06-17/doing-it-wrong

#import "DKDragDropServer.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

#import <objc/runtime.h>

// the key for our associated object.
static char dragKey;
static char contextKey;
static char dataProviderKey;
static char dragDelegateKey;
static char acceptedTypesKey;
static char containsDragViewKey;
static char objectsDictionaryKey;

static DKDragDropServer *sharedInstance = nil;

NSString * const DKPasteboardNameDrag = @"dragkit-drag";

@interface DKDragDropServer ()

@property (nonatomic, strong) UIView *originalView;
@property (nonatomic, strong) UIView *draggedView;
@property (nonatomic, strong) UILongPressGestureRecognizer *dragRecognizer;

@property (nonatomic, strong) UIView *lastView;
@property (nonatomic, assign) BOOL targetIsChanged;
@property (nonatomic, assign) BOOL targetIsOriginalView;
@property (nonatomic, strong) UIView *dk_holdingArea;
@property (nonatomic, strong) NSArray *dk_currentDragTypes;
@property (nonatomic, strong) NSMutableArray *dk_dropTargets;

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

- (BOOL)dk_dragPasteboard:(UIPasteboard *)pasteboard conformsToTypes:(NSArray *)types
{
	for (NSString *type in types) {
		for (NSArray *dragTypes in [pasteboard pasteboardTypesForItemSet:nil]) {

			if ([dragTypes containsObject:@"dragkit.metadata"]) continue;
			
			for (NSArray *individualType in dragTypes) {
				if (UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)individualType)) {
					return YES;
				}
			}
		}
	}
	
	return NO;
}

- (void)registerApplicationWithTypes:(NSArray *)types
{	
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
	NSDictionary *meta = nil;
    
    NSData *metadata = [[dragPasteboard valuesForPasteboardType:@"dragkit.metadata" inItemSet:nil] lastObject];
    
    if(metadata)
        meta = [NSKeyedUnarchiver unarchiveObjectWithData:metadata];
	
	if (meta) {
		// we have a drag in progress.
		
		if ([self dk_dragPasteboard:dragPasteboard conformsToTypes:types]) {
			// create and show the holding area.
			[self dk_showHoldingAreaForPasteboard:dragPasteboard];
		}
	}
}

- (void)addSimultaneousRecognitionWithGesture:(UIGestureRecognizer*)gestureRecognizer
{
    [self.dragRecognizer requireGestureRecognizerToFail:gestureRecognizer];
}

#pragma mark -
#pragma mark Marking Views

- (void)markViewAsDraggable:(UIView *)draggableView forDrag:(NSString *)dragID withDataSource:(NSObject <DKDragDataProvider> *)dragDataSource context:(void *)context
{
	objc_setAssociatedObject(draggableView, &dragKey, dragID, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(draggableView, &contextKey, (__bridge id)(context), OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(draggableView, &dataProviderKey, dragDataSource, OBJC_ASSOCIATION_ASSIGN);
}

- (void)markViewAsDropTarget:(UIView *)dropView forTypes:(NSArray *)types withDelegate:(NSObject <DKDragDelegate> *)dropDelegate
{
	objc_setAssociatedObject(dropView, &containsDragViewKey, [NSNumber numberWithBool:NO], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(dropView, &acceptedTypesKey, types, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(dropView, &dragDelegateKey, dropDelegate, OBJC_ASSOCIATION_ASSIGN);
	
    if(self.dk_dropTargets == nil) {
        self.dk_dropTargets = [[NSMutableArray alloc] init];
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
	objc_setAssociatedObject(draggableView, &contextKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(draggableView, &dataProviderKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (void)unmarkDropTarget:(UIView *)dropView
{
	objc_setAssociatedObject(dropView, &acceptedTypesKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(dropView, &dragDelegateKey, nil, OBJC_ASSOCIATION_ASSIGN);
	objc_setAssociatedObject(dropView, &containsDragViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self.dk_dropTargets removeObject:dropView];
    
    if(![self.dk_dropTargets count]) {
        [[self dk_rootView] removeGestureRecognizer:self.dragRecognizer];
        self.dragRecognizer = nil;
    }
}

- (void)dk_createDragPasteboardForView:(UIView *)view position:(CGPoint)point
{
	//grab the associated objects.
	NSString *dropIdentifier = objc_getAssociatedObject(view, &dragKey);
	void *dropContext = (__bridge void *)(objc_getAssociatedObject(view, &contextKey));
	NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
	
	// if we are the data provider, that means we already have a pasteboard.
	if (dataProvider == (id<DKDragDataProvider>)self) {
		// set up our current drag types.
		
		UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
		self.dk_currentDragTypes = [[NSArray alloc] initWithArray:[[dragPasteboard pasteboardTypesForItemSet:nil] lastObject]];
		return;
	}
	
	// clear the drag pasteboard.
	[self dk_clearDragPasteboard];
	
	// ask for the data and construct a UIPasteboard.
	UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
	dragPasteboard.persistent = YES;
	
	// associate metadata with the pasteboard.
	NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
	
	// add the drag image. if none is set, we can use default.
	[metadata setObject:UIImagePNGRepresentation(self.background) forKey:@"dragImage"];
    	
	// set our metadata on our private metadata type.
	[dragPasteboard addItems:[NSArray arrayWithObject:[NSDictionary dictionaryWithObject:[NSKeyedArchiver archivedDataWithRootObject:metadata]
																				  forKey:@"dragkit.metadata"]]];
	
	// go through each type supported by the drop target
	// and request the data for that type from the data source.
	
	NSArray *advertisedTypes = [dataProvider typesSupportedForDrag:dropIdentifier forView:view context:dropContext];
	NSMutableArray *pasteboardTypes = [NSMutableArray array];
	NSMutableArray *justTypes = [NSMutableArray array];
    NSMutableDictionary *objectsDictionary = [NSMutableDictionary dictionary];
	for (NSString *type in advertisedTypes) {
        
        NSData *data = nil;
        id object = nil;
        
        if([dataProvider respondsToSelector:@selector(dataForType:withDrag:forView:position:context:)])
            data = [dataProvider dataForType:type withDrag:dropIdentifier forView:view position:point context:dropContext];
        
        if([dataProvider respondsToSelector:@selector(objectForType:withDrag:forView:position:context:)])
            object = [dataProvider objectForType:type withDrag:dropIdentifier forView:view position:point context:dropContext];
		
		if (data || object)
			[justTypes addObject:type];

        if(data) [pasteboardTypes addObject:[NSDictionary dictionaryWithObject:data forKey:type]];
        if(object) [objectsDictionary setObject:object forKey:type];
    }
    if([objectsDictionary count] > 0) {
        objc_setAssociatedObject(dragPasteboard, &objectsDictionaryKey, [NSDictionary dictionaryWithDictionary:objectsDictionary], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    self.dk_currentDragTypes = [[NSArray alloc] initWithArray:justTypes];
    
    [dragPasteboard addItems:pasteboardTypes];
}

#pragma mark -
#pragma mark Dragging Callback

- (void)dk_handleLongPress:(UIGestureRecognizer *)sender
{    
	CGPoint touchPoint = [sender locationInView:[self dk_rootView]];
	UIView *droppedTarget;
	UIView *dragView;
	
	switch ([sender state]) {
		case UIGestureRecognizerStateBegan: {
			
            self.initialTouchPoint = touchPoint;
			
			// create the necessary view and animate it.
			[self dk_hideHoldingArea];
			
			dragView = [self dk_dragViewUnderPoint:touchPoint];
            CGPoint positionInView = [[self dk_rootView] convertPoint:touchPoint toView:dragView];
			
			if (!dragView) {
				[sender setState:UIGestureRecognizerStateFailed];
				return;
			}
            
			if(![self dk_shouldStartDragForView:dragView position:positionInView]) {
                [sender setState:UIGestureRecognizerStateFailed];
                return;
            }
            
			self.originalView = dragView;
            
            [self dk_signalDragWillStartForView:dragView position:positionInView];
			
			[self dk_displayDragViewForView:self.originalView atPoint:touchPoint];
			
			[self dk_createDragPasteboardForView:dragView position:positionInView];
			[self dk_signalDragDidStartForView:dragView position:positionInView];
            
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
            [self dk_signalDragWillFinishForView:self.originalView position:positionInView];
            
			droppedTarget = [self dk_dropTargetHitByPoint:self.lastPoint];
			
			NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(droppedTarget, &dragDelegateKey);
			
			if (droppedTarget) {
				
				if ([dragDelegate respondsToSelector:@selector(drag:completedOnTargetView:withDragPasteboard:context:)]) {
					
					NSString *dropIdentifier = objc_getAssociatedObject(droppedTarget, &dragKey);
					void *dropContext = (__bridge void *)(objc_getAssociatedObject(droppedTarget, &contextKey));
					
					UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:NO];
					[dragDelegate drag:dropIdentifier completedOnTargetView:droppedTarget withDragPasteboard:dragPasteboard context:dropContext];
					[dragPasteboard setItems:nil];
				}
				
				if ([dragDelegate respondsToSelector:@selector(drag:completedOnTargetView:withObjectsDictionary:context:)]) {
					
					NSString *dropIdentifier = objc_getAssociatedObject(droppedTarget, &dragKey);
					void *dropContext = (__bridge void *)(objc_getAssociatedObject(droppedTarget, &contextKey));

					UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:NO];
                    NSDictionary *objectsDictionary = objc_getAssociatedObject(dragPasteboard, &objectsDictionaryKey);					
					[dragDelegate drag:dropIdentifier completedOnTargetView:droppedTarget withObjectsDictionary:objectsDictionary context:dropContext];
                    
                    objc_setAssociatedObject(dragPasteboard, &objectsDictionaryKey, nil, OBJC_ASSOCIATION_RETAIN);
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
            
            
            [self dk_signalDragDidFinishForView:self.originalView position:positionInView];
			
			break;
        }
		case UIGestureRecognizerStateCancelled: {

            CGPoint positionInView = [[self dk_rootView] convertPoint:self.initialTouchPoint toView:self.originalView];
            [self dk_signalDragWillFinishForView:self.originalView position:positionInView];
			[self cancelDrag];
            
            [self dk_signalDragDidFinishForView:self.originalView position:positionInView];
			
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

- (UIView *)dk_dragViewUnderPoint:(CGPoint)point
{
	return [self dk_viewContainingKey:&dataProviderKey forPoint:point];
}

- (UIView *)dk_dropTargetHitByPoint:(CGPoint)point
{
	
	for (UIView *dropTarget in self.dk_dropTargets) {
		CGRect frameInWindow = [[dropTarget superview] convertRect:dropTarget.frame toView:[self dk_rootView]];
		if (CGRectContainsPoint(frameInWindow, point)) {
			NSArray *acceptedTypes = objc_getAssociatedObject(dropTarget, &acceptedTypesKey);
			if ([[NSSet setWithArray:acceptedTypes] intersectsSet:[NSSet setWithArray:self.dk_currentDragTypes]]) {
				return dropTarget;
			}
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
	NSArray *acceptedTypes = objc_getAssociatedObject(dropTarget, &acceptedTypesKey);
	NSObject<DKDragDelegate> *dragDelegate = objc_getAssociatedObject(dropTarget, &dragDelegateKey);
	BOOL containsDragView = [(NSNumber *)objc_getAssociatedObject(dropTarget, &containsDragViewKey) boolValue];
	
	if ([[NSSet setWithArray:acceptedTypes] intersectsSet:[NSSet setWithArray:self.dk_currentDragTypes]]) {
		
		
		if (!containsDragView && [dragDelegate respondsToSelector:@selector(dragDidEnterTargetView:)]) {
			[dragDelegate dragDidEnterTargetView:dropTarget];
		}
        else if(containsDragView && [dragDelegate respondsToSelector:@selector(dragDidUpdatePositionOverTargetView:position:withObjectsDictionary:)]) {
            
            CGPoint positionInTargetView = [[self dk_rootView] convertPoint:point toView:dropTarget];
            
            UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
            NSDictionary *objectsDictionary = objc_getAssociatedObject(dragPasteboard, &objectsDictionaryKey);
            
            [dragDelegate dragDidUpdatePositionOverTargetView:dropTarget position:positionInTargetView withObjectsDictionary:objectsDictionary];
        }

		self.lastView = dropTarget;
		
		objc_setAssociatedObject(dropTarget, &containsDragViewKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

- (UIImage *)dk_generateImageFromView:(UIView *)theView
{	
	if (!theView) return nil;
	
	UIGraphicsBeginImageContext(theView.bounds.size);
	
	[theView.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	
	return resultingImage;
}

#pragma mark -
#pragma mark Drag View Creation

- (void)dk_displayDragViewForView:(UIView *)draggableView atPoint:(CGPoint)point
{
	if (!self.draggedView) {
		
		// transition from the dragImage to our view.
		NSString *dropIdentifier = objc_getAssociatedObject(draggableView, &dragKey);
		void *dropContext = (__bridge void *)(objc_getAssociatedObject(draggableView, &contextKey));
		NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(draggableView, &dataProviderKey);
		
		self.background = nil;
		
        BOOL shouldUseViewAsDragImage = NO;
        if([dataProvider respondsToSelector:@selector(drag:shouldUseViewAsDragImageForView:)])
            shouldUseViewAsDragImage = [dataProvider drag:dropIdentifier shouldUseViewAsDragImageForView:draggableView];

        if(shouldUseViewAsDragImage) {
            UIGraphicsBeginImageContext(draggableView.bounds.size);
            [draggableView.layer renderInContext:UIGraphicsGetCurrentContext()];
            self.background = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        else {
            if ([dataProvider respondsToSelector:@selector(imageForDrag:forView:position:context:)]) {
                CGPoint positionInView = [[self dk_rootView] convertPoint:point toView:draggableView];
                self.background = [dataProvider imageForDrag:dropIdentifier forView:draggableView position:positionInView context:dropContext];
            } else {
                
                UIPasteboard *dragPasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
                
                NSDictionary *metadata = [NSKeyedUnarchiver unarchiveObjectWithData:[[dragPasteboard valuesForPasteboardType:@"dragkit.metadata" inItemSet:nil] lastObject]];
                
                NSData *imageData = [metadata objectForKey:@"dragImage"];
                
                if (imageData) {
                    self.background = [UIImage imageWithData:imageData];
                }
                
                if (!imageData || !self.background) {
                    self.background = [UIImage imageNamed:@"drag_default.png"];
                }
            }
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

- (void)dk_clearDragPasteboard
{
	self.dk_currentDragTypes = nil;
	
	UIPasteboard *pasteboard = [UIPasteboard pasteboardWithName:DKPasteboardNameDrag create:YES];
	pasteboard.persistent = NO;
	[pasteboard setItems:nil];
}

- (void)cancelDrag
{	
	[self dk_clearDragPasteboard];
	
	CGPoint originalLocation = [[self.originalView superview] convertPoint:self.originalView.center toView:[self dk_rootView]];
    
    [UIView animateWithDuration:0.25f animations:^{
        self.draggedView.center = originalLocation;
        self.draggedView.alpha = 0.5;
    } completion:^(BOOL finished) {
        [self.draggedView removeFromSuperview];
		self.draggedView = nil;
    }];
}

#pragma mark -
#pragma Helpers

- (BOOL)dk_shouldStartDragForView:(UIView *)view position:(CGPoint)position
{
	NSString *dropIdentifier = objc_getAssociatedObject(view, &dragKey);
	void *dropContext = (__bridge void *)(objc_getAssociatedObject(view, &contextKey));
	NSObject<DKDragDataProvider> *dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
    
    if([dataProvider respondsToSelector:@selector(shouldStartDrag:forView:position:context:)]) {
        return [dataProvider shouldStartDrag:dropIdentifier forView:view position:position context:dropContext];
    }
    return YES;
}

#pragma mark -
#pragma mark Holding Area Drawing

- (void)dk_showHoldingAreaForPasteboard:(UIPasteboard *)pasteboard
{	
	UIView *mainView = [self dk_rootView];
	
	self.dk_holdingArea = [[UIView alloc] initWithFrame:mainView.bounds];
	self.dk_holdingArea.backgroundColor = [UIColor blackColor];
	self.dk_holdingArea.alpha = 0.0;
	
	[mainView addSubview:self.dk_holdingArea];
	
	[self dk_displayDragViewForView:nil atPoint:CGPointMake(mainView.frame.size.width / 2.0, mainView.frame.size.height / 2.0)];
	self.draggedView.alpha = 0.0;
	
	// use associated objects to attach our drag identifier.
	objc_setAssociatedObject(self.draggedView, &dragKey, @"DragKit-Internal", OBJC_ASSOCIATION_COPY_NONATOMIC);
	// attach the drag delegate.
	objc_setAssociatedObject(self.draggedView, &dataProviderKey, self, OBJC_ASSOCIATION_ASSIGN);
	
	UIPanGestureRecognizer *dragGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleLongPress:)];
	[self.draggedView addGestureRecognizer:dragGesture];
		
    [UIView animateWithDuration:0.25f animations:^{
        self.dk_holdingArea.alpha = 0.4;
        self.draggedView.alpha = 1.0;
    }];
}

- (void)dk_hideHoldingArea
{    
    [UIView animateWithDuration:0.25f animations:^{
        self.dk_holdingArea.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.dk_holdingArea removeFromSuperview];
    }];
}

- (void)dk_signalDragWillStartForView:(UIView *)view position:(CGPoint)point
{
    NSString *dragID = objc_getAssociatedObject(view, &dragKey);
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
    
    if([dataProvider respondsToSelector:@selector(drag:willStartForView:position:)]) {
        [dataProvider drag:dragID willStartForView:view position:point];
    }
}

- (void)dk_signalDragDidStartForView:(UIView *)view position:(CGPoint)point
{
    NSString *dragID = objc_getAssociatedObject(view, &dragKey);
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
    
    if([dataProvider respondsToSelector:@selector(drag:didStartForView:position:)]) {
        [dataProvider drag:dragID didStartForView:view position:point];
    }
}

- (void)dk_signalDragWillFinishForView:(UIView *)view position:(CGPoint)point
{
    NSString *dragID = objc_getAssociatedObject(view, &dragKey);
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
    
    if([dataProvider respondsToSelector:@selector(drag:willFinishForView:position:)]) {
        [dataProvider drag:dragID willFinishForView:view position:point];
    }
}

- (void)dk_signalDragDidFinishForView:(UIView *)view position:(CGPoint)point
{
    NSString *dragID = objc_getAssociatedObject(view, &dragKey);
    id<DKDragDataProvider, NSObject> dataProvider = objc_getAssociatedObject(view, &dataProviderKey);
    
    if([dataProvider respondsToSelector:@selector(drag:didFinishForView:position:)]) {
        [dataProvider drag:dragID didFinishForView:view position:point];
    }
    
    self.originalView = nil;
}

@end
