//
//  MainViewController.h
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class NoodleLineNumberView;
@class GlobalAddress;
@interface MainViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
@property (unsafe_unretained) IBOutlet NSTextView *scriptView;
@property (weak) IBOutlet NSScrollView *scrollView;
@property (nonatomic, retain) NoodleLineNumberView	*lineNumberView;
@end


@interface StructDef : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSNumber *size;
@property (nonatomic, retain) GlobalAddress *address;
@property (nonatomic, retain) NSMutableDictionary *members;
@property (nonatomic, retain) NSString *type;
@end