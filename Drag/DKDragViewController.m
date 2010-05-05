    //
//  DKDragViewController.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDragViewController.h"

#import "DKDragDropServer.h"
#import "DKDragView.h"

@implementation DKDragViewController

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	NSLog(@"frame: %@", NSStringFromCGRect(self.view.frame));
	
	DKDragView *dragView = [[DKDragView alloc] initWithFrame:CGRectMake(100, 100, 400, 100)];
	
	[[DKDragDropServer sharedServer] markViewAsDraggable:dragView];
	
	[self.view addSubview:dragView];
	NSLog(@"dragFrame: %@", NSStringFromCGRect(dragView.frame));
	[dragView release];
	
	
	UIView *otherView = [[UIView alloc] initWithFrame:CGRectMake(100, 500, 400, 100)];
	otherView.backgroundColor = [UIColor yellowColor];
	[self.view addSubview:otherView];
	NSLog(@"otherFrame: %@", NSStringFromCGRect(otherView.frame));
	[otherView release];
	
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
