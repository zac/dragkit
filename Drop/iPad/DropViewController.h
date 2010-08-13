//
//  DropViewController.h
//  Drop
//
//  Created by Zac White on 8/12/10.
//  Copyright 2010 Gravity Mobile. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DragKit.h"

@interface DropViewController : UIViewController <DKDragDelegate> {
	IBOutlet UILabel *dropWell;
}

@property (nonatomic, retain) IBOutlet UILabel *dropWell;

@end
