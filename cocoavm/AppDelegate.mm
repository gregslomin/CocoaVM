//
//  AppDelegate.m
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import "AppDelegate.h"
#import <objc/runtime.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [[NSNotificationCenter defaultCenter] addObserverForName:@"calledNative" object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self showTheSheet:note.userInfo];
    }];
    

}

- (void) showTheSheet:(NSDictionary*)data{
    
    NSNumber* numFields = data[@"returnCount"];
    int num = [numFields intValue];
    if(num == 0)
        return;
    else if(num == 1)
    {
        [self.textField1 setHidden:YES];
        [self.textField3 setHidden:YES];
    }
    else if(num == 3)
    {
        [self.textField1 setHidden:NO];
        [self.textField3 setHidden:NO];
    }
    [self.window setIgnoresMouseEvents:YES];
    [NSApp beginSheet:self.theSheet
       modalForWindow:(NSWindow *)self.window
        modalDelegate:self
       didEndSelector:nil
          contextInfo:nil];
    
}
- (IBAction)done:(id)sender {
    [self endTheSheet];
}

-(void)endTheSheet{

    if([self.textField1 isHidden] == YES)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"nativesReturned" object:nil userInfo:@{@"retVal":self.textField2.stringValue}];
    }
    else
    {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"nativesReturned" object:nil userInfo:@{@"retVal1":self.textField1.stringValue, @"retVal2":self.textField2.stringValue, @"retVal3":self.textField3.stringValue}];
    }
    
    [NSApp endSheet:self.theSheet];
    [self.theSheet orderOut:nil];
    [self.window setIgnoresMouseEvents:NO];
    
}
@end
