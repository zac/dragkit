//
//  DKApplicationRegistration.m
//  Drag
//
//  Created by Zac White on 6/21/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKApplicationRegistration.h"

#import "DKDragDropServer.h"

@implementation DKApplicationRegistration

@synthesize applicationName, applicationBundleIdentifier;
@synthesize icon114, icon72, icon57, iconPrerendered;
@synthesize frameworkVersion;
@synthesize urlScheme, supportedDragTypes;

+ (DKApplicationRegistration *)registrationWithDragTypes:(NSArray *)dragTypes {
	
	DKApplicationRegistration *appRegistration = [[DKApplicationRegistration alloc] init];
	
	NSMutableSet *iconNames = [[NSMutableSet alloc] init];
	
	NSArray *allIcons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFiles"];
	if ([allIcons count]) [iconNames addObjectsFromArray:allIcons];
	
	NSString *mainIcon = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];
	
	if (mainIcon) [iconNames addObject:mainIcon];
	
	for (NSString *iconPath in iconNames) {
		//read each icon in and determine the size.
		NSString *fullPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:iconPath];
		NSLog(@"full: %@", fullPath);
	}
	
	appRegistration.applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	appRegistration.applicationBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	
	appRegistration.iconPrerendered = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIPrerenderedIcon"] boolValue];
	appRegistration.frameworkVersion = [DKDragDropServer versionString];
	appRegistration.supportedDragTypes = dragTypes;
	
	appRegistration.urlScheme = [NSString stringWithFormat:@"x-drag-%@", [[NSBundle mainBundle] bundleIdentifier]];
	
	return [appRegistration autorelease];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder*)coder {
	if (!(self = [super init])) return nil;
	
	self.applicationName = [coder decodeObjectForKey:@"applicationName"];
	self.applicationBundleIdentifier = [coder decodeObjectForKey:@"applicationBundleIdentifier"];
	
	self.icon114 = [coder decodeObjectForKey:@"icon114"];
	self.icon72 = [coder decodeObjectForKey:@"icon72"];
	self.icon57 = [coder decodeObjectForKey:@"icon57"];
	
	self.iconPrerendered = [[coder decodeObjectForKey:@"iconPrerendered"] boolValue];
	self.frameworkVersion = [coder decodeObjectForKey:@"frameworkVersion"];
	self.supportedDragTypes = [coder decodeObjectForKey:@"supportedDragTypes"];
	self.urlScheme = [coder decodeObjectForKey:@"urlScheme"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
	
	[coder encodeObject:self.applicationName forKey:@"applicationName"];
	[coder encodeObject:self.applicationBundleIdentifier forKey:@"applicationBundleIdentifier"];
	
	[coder encodeObject:UIImagePNGRepresentation(self.icon114) forKey:@"icon114"];
	[coder encodeObject:UIImagePNGRepresentation(self.icon72) forKey:@"icon72"];
	[coder encodeObject:UIImagePNGRepresentation(self.icon57) forKey:@"icon57"];
	
	[coder encodeObject:[NSNumber numberWithBool:self.iconPrerendered] forKey:@"iconPrerendered"];
	[coder encodeObject:self.frameworkVersion forKey:@"frameworkVersion"];
	[coder encodeObject:self.supportedDragTypes forKey:@"supportedDragTypes"];
	[coder encodeObject:self.urlScheme forKey:@"urlScheme"];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@: %@ (%@)", [super description], self.applicationName, self.applicationBundleIdentifier];
}

- (void)dealloc {
	
	self.applicationName = nil;
	self.applicationBundleIdentifier = nil;
	
	self.icon114 = nil;
	self.icon72 = nil;
	self.icon57 = nil;
	
	self.frameworkVersion = nil;
	
	self.supportedDragTypes = nil;
	
	self.urlScheme = nil;
	
	[super dealloc];
}

@end
