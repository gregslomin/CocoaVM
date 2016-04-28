//
//  AppDelegate.h
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (unsafe_unretained) IBOutlet NSPanel *theSheet;
@property (weak) IBOutlet NSTextField *textField3;
@property (weak) IBOutlet NSTextField *textField2;
@property (weak) IBOutlet NSTextField *textField1;

@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSButton *donePressed;
@end
