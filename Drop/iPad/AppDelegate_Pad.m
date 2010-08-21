//
//  AppDelegate_Pad.m
//  Drop
//
//  Created by Zac White on 4/20/10.
//  Copyright Gravity Mobile 2010. All rights reserved.
//

#import "AppDelegate_Pad.h"

#import "DropViewController.h"

@implementation AppDelegate_Pad

@synthesize window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	
    // Override point for customization after application launch
	
	DropViewController *dropViewController = [[DropViewController alloc] initWithNibName:@"DropViewController" bundle:nil];
	[window addSubview:dropViewController.view];
	
    [window makeKeyAndVisible];
	
	[[DKDragDropServer sharedServer] registerApplicationWithTypes:[NSArray arrayWithObject:@"public.text"]];
	
	return YES;
}


- (void)dealloc {
    [window release];
    [super dealloc];
}


@end
