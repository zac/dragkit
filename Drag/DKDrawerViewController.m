    //
//  DKDrawerViewController.m
//  Drag
//
//  Created by Zac White on 6/19/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDrawerViewController.h"

@implementation DKDrawerViewController

@synthesize gridView;

- (id)init {
	if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
	
	
	
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
	
	contentView.backgroundColor = [UIColor redColor];
	
	self.gridView = [[[AQGridView alloc] initWithFrame:CGRectZero] autorelease];
	self.gridView.dataSource = self;
	
	self.gridView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
	
	[contentView addSubview:self.gridView];
	self.view = contentView;
	[contentView release];
}

#pragma mark -
#pragma mark AQGridView Data Source

- (NSUInteger) numberOfItemsInGridView: (AQGridView *) theGridView {
	return 5;
}

- (AQGridViewCell *) gridView: (AQGridView *) theGridView cellForItemAtIndex: (NSUInteger) index {
	static NSString *CellIdentifier = @"Cell";
    
    AQGridViewCell *cell = [theGridView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[AQGridViewCell alloc] initWithFrame:CGRectMake(0, 0, 100, 100) reuseIdentifier:CellIdentifier] autorelease];
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
