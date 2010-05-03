//
//  DKDragServer.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DKDraggableView.h"

@interface DKDragDropServer : NSObject {
	BOOL dragWindowVisible;
}

@property (nonatomic) BOOL dragWindowVisible;

- (void)displayDragWindowForDragView:(UIView<DKDraggableViewProtocol> *)draggableView;

+ (id)sharedServer;

@end
