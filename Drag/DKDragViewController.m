    //
//  DKDragViewController.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDragViewController.h"

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

#pragma mark -
#pragma mark DKDragDataProvider Methods

//array of types supported by view.
- (NSArray *)typesForView:(UIView *)dragView {
	return nil;
}

//request the data from the view.
- (NSData *)dataForType:(NSString *)type forView:(UIView *)dragView {
	return nil;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	NSLog(@"frame: %@", NSStringFromCGRect(self.view.frame));
	
	DKDragView *dragView = [[DKDragView alloc] initWithFrame:CGRectMake(100, 100, 400, 100)];
	dragView.topLabel.text = @"Testing!!";
	dragView.bottomLabel.text = @"1.2.3.";
	
	[[DKDragDropServer sharedServer] markViewAsDraggable:dragView forDrag:@"MainDrag" withDataSource:self context:nil];
	
	[self.view addSubview:dragView];
	NSLog(@"dragFrame: %@", NSStringFromCGRect(dragView.frame));
	[dragView release];
	
	
	UIView *otherView = [[UIView alloc] initWithFrame:CGRectMake(100, 500, 400, 100)];
	otherView.backgroundColor = [UIColor yellowColor];
	
	[[DKDragDropServer sharedServer] markViewAsDropTarget:otherView withDelegate:self];
	
	[self.view addSubview:otherView];
	NSLog(@"otherFrame: %@", NSStringFromCGRect(otherView.frame));
	[otherView release];
	
}

- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type {
	return YES;
}

- (void)dragDidEnterTargetView:(UIView *)targetView {
	
}

- (void)dragDidLeaveTargetView:(UIView *)targetView {
	
}

- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView context:(void *)context {
	NSLog(@"drag: %@ completedOnTargetView:%@ context:%p", dropID, targetView, context);
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
