//
//  BIgEndianReader.m
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import "BIgEndianReader.h"
@interface BIgEndianReader()
@property (nonatomic, assign) Byte* bytes;
@property (nonatomic, assign) NSUInteger index;
@end

@implementation BIgEndianReader
-(id)initWithData:(NSData*)data
{
    self = [self init];
    if(self)
    {
        
    }
    return self;
}
@end
