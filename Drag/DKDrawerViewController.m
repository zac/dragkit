    //
//  DKDrawerViewController.m
//  Drag
//
//  Created by Zac White on 6/19/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDrawerViewController.h"

#import "DKDrawerCell.h"

#import "DKApplicationRegistration.h"

@implementation DKDrawerViewController

@synthesize gridView, supportedApplications, externalApplications;

- (id)init {
	if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
	
	self.supportedApplications = [[DKDragDropServer sharedServer] registeredApplications];
	self.externalApplications = [NSMutableArray array];
	
	return self;
}

- (void)addExternalApplication:(DKApplicationRegistration *)external {
	[self.externalApplications addObject:external];
	
	NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self.supportedApplications count] + [self.externalApplications count] - 1, 1)];
	[self.gridView insertItemsAtIndices:indexSet withAnimation:AQGridViewItemAnimationFade];
}

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

#pragma mark -
#pragma mark Drag Delegate

- (BOOL)targetView:(UIView *)targetView acceptsDropForType:(NSString *)type {
	return YES;
}

- (void)dragDidEnterTargetView:(UIView *)targetView {
	NSLog(@"enter: %@", targetView);
}

- (void)dragDidLeaveTargetView:(UIView *)targetView {
	NSLog(@"leave: %@", targetView);
}

- (void)drag:(NSString *)dropID completedOnTargetView:(UIView *)targetView withDragPasteboard:(UIPasteboard *)dragPasteboard context:(void *)context {
	NSLog(@"completed drop %@ on %@ with %@.", dropID, targetView, dragPasteboard);
	//take our pasteboard and make it persistent.
	//launch the appropriate application using our url scheme with the persistent pasteboard's name as a parameter.
	
	NSMutableDictionary *metadata = [[NSMutableDictionary alloc] init];
	
	// add the drag image. if none is set, we can use default.
	[metadata setObject:[NSData data] forKey:@"dragImage"];
	
	// add the registration for the application that we're dragging from.
	[metadata setObject:[NSNull null] forKey:@"draggingApplication"];
	
	// set our metadata on our private metadata type.
	[dragPasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:metadata] forPasteboardType:@"dragkit.metadata"];
	[metadata release];
	
	// make sure our drag pasteboard sticks around.
	dragPasteboard.persistent = YES;
	
	// open the application with the url scheme pointing to our drag pasteboard.
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"TODO://"]];
}

#pragma mark -
#pragma mark AQGridView Data Source

- (NSUInteger) numberOfItemsInGridView: (AQGridView *) theGridView {
	return [self.supportedApplications count] + [self.externalApplications count];
}

- (AQGridViewCell *) gridView: (AQGridView *) theGridView cellForItemAtIndex: (NSUInteger) index {
	static NSString *CellIdentifier = @"Cell";
    
	DKDrawerCell *cell = (DKDrawerCell *)[theGridView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[DKDrawerCell alloc] initWithFrame:CGRectMake(0, 0, 50, 50) reuseIdentifier:CellIdentifier] autorelease];
    }
    
	DKApplicationRegistration *appRegistration = nil;
	if (index < [self.supportedApplications count]) {
		appRegistration = [self.supportedApplications objectAtIndex:index];
		cell.backgroundColor = [UIColor grayColor];
	} else {
		appRegistration = [self.externalApplications objectAtIndex:index - [self.supportedApplications count]];
		cell.backgroundColor = [UIColor greenColor];
	}
	
	[[DKDragDropServer sharedServer] unmarkDropTarget:cell];
	[[DKDragDropServer sharedServer] markViewAsDropTarget:cell forTypes:appRegistration.supportedDragTypes withDelegate:self];
	
	cell.selectionStyle = AQGridViewCellSelectionStyleGlow;
	
    return cell;
}

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
