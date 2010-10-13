//
//  DragViewController.h
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DKDragDropServer.h"

@interface DragViewController_Phone : UIViewController <DKDragDataProvider, DKDragDelegate, UITabBarDelegate> {
	IBOutlet UILabel *top;
	IBOutlet UIView *drop;
}

@property (nonatomic, retain) UILabel *top;
@property (nonatomic, retain) UIView *drop;

- (IBAction)reset:(id)sender;
- (IBAction)segmentChanged:(id)sender;
- (IBAction)navBar:(id)sender;
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;
	
@end
