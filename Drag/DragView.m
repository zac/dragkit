//
//  DKDragView.m
//  Drag
//
//  Created by Zac White on 4/20/10.
//  Copyright 2010 Zac White. All rights reserved.
//

#import "DragView.h"


@implementation DragView

@synthesize thumbnailView, topLabel, bottomLabel;

- (id)initWithFrame:(CGRect)theFrame {
    if (!(self = [super initWithFrame:theFrame])) return nil;
		
	self.thumbnailView = [[[UIImageView alloc] initWithFrame:CGRectZero] autorelease];
	self.topLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	self.bottomLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	
	self.backgroundColor = [UIColor redColor];
	
	[self addSubview:self.thumbnailView];
	[self addSubview:self.topLabel];
	[self addSubview:self.bottomLabel];
	
	return self;
}

#define MARGIN 10

- (void)layoutSubviews {
	[super layoutSubviews];
	
	int thumbnailWidth = self.frame.size.height - MARGIN * 2;
	
	self.thumbnailView.frame = CGRectMake(MARGIN, MARGIN, thumbnailWidth, thumbnailWidth);
	
	[self.topLabel sizeToFit];
	self.topLabel.frame = CGRectMake(MARGIN + thumbnailWidth, MARGIN, MARGIN * 3 + (self.frame.size.width - thumbnailWidth), self.topLabel.frame.size.height);
	
	[self.bottomLabel sizeToFit];
	self.bottomLabel.frame = CGRectMake(MARGIN + thumbnailWidth, CGRectGetMaxY(self.topLabel.frame), MARGIN * 3 + (self.frame.size.width - thumbnailWidth), self.bottomLabel.frame.size.height);
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
