//
//  DragViewController.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DragViewController_Phone.h"

#import "DragView.h"

@implementation DragViewController_Phone

@synthesize top, drop;


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
          
	[[DKDragDropServer sharedServer] markViewAsDraggable:self.top forDrag:@"MainDrag" withDataSource:self context:nil];
	
	[[DKDragDropServer sharedServer] markViewAsDropTarget:self.drop forTypes:[NSArray arrayWithObject:@"public.text"] withDelegate:self];
}

- (void)reset:(id)sender {
	NSLog(@"RESET.");
	[[DKDragDropServer sharedServer] resetRegistrationDatabase];
	[sender setBackgroundColor:[UIColor redColor]];
	
}

- (IBAction)segmentChanged:(id)sender {
	NSLog(@"Segment Changed: %d", [sender selectedSegmentIndex]);
}

- (IBAction)navBar:(id)sender {
	NSLog(@"navBar button clicked");
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	NSLog(@"tabBar item %@ selected", item.title);
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
	
	self.top = nil;
	self.drop = nil;
}


@end
