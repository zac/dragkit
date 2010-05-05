//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DKDragDropServer : NSObject {
	UIWindow *dragWindow;
	BOOL dragWindowVisible;
}

@property (nonatomic) BOOL dragWindowVisible;
@property (nonatomic, retain) UIWindow *dragWindow;

- (void)markViewAsDraggable:(UIView *)draggableView;

- (void)moveDragWindowForView:(UIView *)draggableView toPoint:(CGPoint)point;

+ (id)sharedServer;

@end
