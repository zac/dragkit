//
//  AppDelegate_Pad.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright Zac White 2010. All rights reserved.
//

#import "AppDelegate_Pad.h"

#import "DragViewController.h"

@implementation AppDelegate_Pad

@synthesize window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	
    // Override point for customization after application launch
	
	DragViewController *dragViewController = [[DragViewController alloc] initWithNibName:nil bundle:nil];
	[window addSubview:dragViewController.view];
	
    [window makeKeyAndVisible];
	
	// must be done after the window is key.
	[[DKDragDropServer sharedServer] registerApplicationWithTypes:[NSArray arrayWithObject:@"public.text"]];
	
	return YES;
}


- (void)dealloc {
    [window release];
    [super dealloc];
}


@end
