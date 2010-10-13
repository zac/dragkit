//
//  AppDelegate_Phone.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright Zac White 2010. All rights reserved.
//

#import "AppDelegate_Phone.h"

#import "DragViewController_Phone.h"

@implementation AppDelegate_Phone

@synthesize window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
	
    [window makeKeyAndVisible];
	
	[[DKDragDropServer sharedServer] registerApplicationWithTypes:[NSArray arrayWithObject:@"public.text"]];
	
	return YES;
}


- (void)dealloc {
    [window release];
    [super dealloc];
}


@end
