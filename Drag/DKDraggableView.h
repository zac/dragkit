//
//  DKDraggableView.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DKDraggableViewProtocol

- (void)_handleLongPress:(UIGestureRecognizer *)sender;
- (UIImage *)_generateImageForDrag;

@end


@interface DKDraggableView : UIView <DKDraggableViewProtocol> {

}

@end
