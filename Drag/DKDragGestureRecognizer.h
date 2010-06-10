//
//  DKDragGestureRecognizer.h
//  Drag
//
//  Created by Zac White on 6/9/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIGestureRecognizerSubclass.h>

@class DKDragGestureRecognizer;

@protocol DKDragGestureRecognizerDelegate

- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)dragRecognizer:(DKDragGestureRecognizer *)recognizer touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

@end


@interface DKDragGestureRecognizer : UIGestureRecognizer {
	NSObject<DKDragGestureRecognizerDelegate> *dragDelegate;
	
	
}

- (id)initWithDragDelegate:(NSObject<DKDragGestureRecognizerDelegate> *)newDelegate;

@property (nonatomic, assign) NSObject<DKDragGestureRecognizerDelegate> *dragDelegate;

@property (nonatomic) NSInteger numberOfTapsRequired;
@property (nonatomic) NSInteger numberOfTouchesRequired;

@end
