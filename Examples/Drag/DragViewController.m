//
//  DragViewController.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DragViewController.h"

#import "DragView.h"

@implementation DragViewController

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

- (NSArray *)typesSupportedForDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context {
	return [NSArray arrayWithObject:@"public.text"];
}

//request the data from the view.
- (NSData *)dataForType:(NSString *)type withDrag:(NSString *)dragID forView:(UIView *)dragView context:(void *)context {
	
	if ([type isEqualToString:@"public.text"]) {
		return [@"Testing 1,2,3" dataUsingEncoding:NSUTF8StringEncoding];
	}
	
	return nil;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	NSLog(@"frame: %@", NSStringFromCGRect(self.view.frame));
	
	DragView *dragView = [[DragView alloc] initWithFrame:CGRectMake(100, 100, 400, 100)];
	dragView.topLabel.text = @"Testing!!";
	dragView.bottomLabel.text = @"1.2.3.";
	
	[[DKDragDropServer sharedServer] markViewAsDraggable:dragView forDrag:@"MainDrag" withDataSource:self context:nil];
	
	[self.view addSubview:dragView];
	NSLog(@"dragFrame: %@", NSStringFromCGRect(dragView.frame));
	[dragView release];
	
	
	UIView *otherView = [[UIView alloc] initWithFrame:CGRectMake(100, 500, 400, 100)];
	otherView.backgroundColor = [UIColor yellowColor];
	
	[[DKDragDropServer sharedServer] markViewAsDropTarget:otherView forTypes:[NSArray arrayWithObject:@"public.text"] withDelegate:self];
	
	[self.view addSubview:otherView];
	NSLog(@"otherFrame: %@", NSStringFromCGRect(otherView.frame));
	[otherView release];
	
	UIButton *resetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[resetButton setTitle:@"Reset" forState:UIControlStateNormal];
	[resetButton addTarget:self action:@selector(reset:) forControlEvents:UIControlEventTouchUpInside];
	resetButton.frame = CGRectMake(100, 700, 100, 70);
	
	[self.view addSubview:resetButton];
}

- (void)reset:(id)sender {
	[[DKDragDropServer sharedServer] resetRegistrationDatabase];
}

- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type {
	return YES;
}

- (void)dragDidEnterTargetView:(UIView *)targetView {
	
}

- (void)dragDidLeaveTargetView:(UIView *)targetView {
	
}

- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withDragPasteboard:(UIPasteboard *)dragPasteboard context:(void *)context {
	NSLog(@"drag: %@ completedOnTargetView:%@ dragPasteboard:%@ context:%p", dropID, targetView, dragPasteboard, context);
	
	NSString *text = [[NSString alloc] initWithData:[[dragPasteboard valuesForPasteboardType:@"public.text" inItemSet:nil] lastObject]
										   encoding:NSUTF8StringEncoding];
	NSLog(@"data: %@", text);
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
