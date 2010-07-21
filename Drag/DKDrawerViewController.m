    //
//  DKDrawerViewController.m
//  Drag
//
//  Created by Zac White on 6/19/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDrawerViewController.h"

#import "DKDrawerCell.h"

@implementation DKDrawerViewController

@synthesize gridView, supportedApplications;

- (id)init {
	if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
	
	self.supportedApplications = [[DKDragDropServer sharedServer] registeredApplications];
	
	return self;
}

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	[super loadView];
	
	UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
	
	self.gridView = [[[AQGridView alloc] initWithFrame:CGRectZero] autorelease];
	self.gridView.backgroundColor = [UIColor redColor];
	self.gridView.dataSource = self;
	
	self.gridView.resizesCellWidthToFit = NO;
	
	self.gridView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	[contentView addSubview:self.gridView];
	self.view = contentView;
	[contentView release];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self.gridView reloadData];
}

- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type { return YES; }
- (void)dragDidEnterTargetView:(UIView *)targetView { NSLog(@"enter: %@", targetView); }
- (void)dragDidLeaveTargetView:(UIView *)targetView { NSLog(@"leave: %@", targetView); }
- (void)dropCompletedOnTargetView:(UIView *)targetView withView:(UIView *)theView { NSLog(@"completed drop of %@ on %@.", theView, targetView); }

#pragma mark -
#pragma mark AQGridView Data Source

- (NSUInteger) numberOfItemsInGridView: (AQGridView *) theGridView {
	return [self.supportedApplications count];
}

- (AQGridViewCell *) gridView: (AQGridView *) theGridView cellForItemAtIndex: (NSUInteger) index {
	static NSString *CellIdentifier = @"Cell";
    
	DKDrawerCell *cell = (DKDrawerCell *)[theGridView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[DKDrawerCell alloc] initWithFrame:CGRectMake(0, 0, 50, 50) reuseIdentifier:CellIdentifier] autorelease];
		[[DKDragDropServer sharedServer] markViewAsDropTarget:cell withDelegate:self];
    }
    
	cell.backgroundColor = [UIColor grayColor];
	cell.selectionStyle = AQGridViewCellSelectionStyleGlow;
	
    return cell;
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
	
    self.gridView = nil;
}


- (void)dealloc {
	
    [super dealloc];
}


@end
