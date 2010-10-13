//
//  DKApplicationRegistration.h
//  Drag
//
//  Created by Zac White on 6/21/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DKApplicationRegistration : NSObject {
	
	NSString *applicationName;
	NSString *applicationBundleIdentifier;
	
	// for iPhone 4.
	UIImage *icon114;
	// for iPad.
	UIImage *icon72;
	// for iPhone.
	UIImage *icon57;
	
	// version of framework used to register.
	NSString *frameworkVersion;
	
	//true if the icon is pre-rendered.
	BOOL iconPrerendered;
	
	//the url scheme to launch this app.
	NSString *urlScheme;
	
	//an array of supported drag types.
	NSArray *supportedDragTypes;
}

+ (DKApplicationRegistration *)registrationWithDragTypes:(NSArray *)dragTypes;

@property (nonatomic, copy) NSString *applicationName;
@property (nonatomic, copy) NSString *applicationBundleIdentifier;

@property (nonatomic, retain) UIImage *icon114;
@property (nonatomic, retain) UIImage *icon72;
@property (nonatomic, retain) UIImage *icon57;
@property (nonatomic, copy) NSString *frameworkVersion;
@property (nonatomic) BOOL iconPrerendered;
@property (nonatomic, copy) NSString *urlScheme;
@property (nonatomic, copy) NSArray *supportedDragTypes;

@end
