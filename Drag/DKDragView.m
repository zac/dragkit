//
//  DKDragView.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DKDragView.h"


@implementation DKDragView

@synthesize thumbnailView, topLabel, bottomLabel;

- (id)initWithFrame:(CGRect)theFrame {
    if (!(self = [super initWithFrame:theFrame])) return nil;
		
	self.thumbnailView = [[[UIImageView alloc] initWithFrame:CGRectZero] autorelease];
	self.topLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	self.bottomLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	
	self.backgroundColor = [UIColor redColor];
	
	return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void)dealloc {
	
	self.thumbnailView = nil;
	self.topLabel = nil;
	self.bottomLabel = nil;
	
    [super dealloc];
}


@end
