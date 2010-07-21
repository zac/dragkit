//
//  DKDrawerViewController.h
//  Drag
//
//  Created by Zac White on 6/19/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DKDragDropServer.h"

#import "AQGridView.h"

@interface DKDrawerViewController : UIViewController <AQGridViewDataSource, DKDropDelegate> {
	
	NSArray *supportedApplications;
	
	AQGridView *gridView;
}

@property (nonatomic, retain) NSArray *supportedApplications;
@property (nonatomic, retain) AQGridView *gridView;

@end
