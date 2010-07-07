//
//  AppDelegate_Pad.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright Zac White 2010. All rights reserved.
//

#import "AppDelegate_Pad.h"

#import "DKDragViewController.h"

@implementation AppDelegate_Pad

@synthesize window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	
	[[DKDragDropServer sharedServer] registerApplicationWithTypes:nil];
	
    // Override point for customization after application launch
	
	DKDragViewController *dragViewController = [[DKDragViewController alloc] initWithNibName:nil bundle:nil];
	[window addSubview:dragViewController.view];
	
    [window makeKeyAndVisible];
	
	return YES;
}


- (void)dealloc {
    [window release];
    [super dealloc];
}


@end
