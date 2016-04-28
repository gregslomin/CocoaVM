//
//  main.m
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

int main(int argc, const char * argv[])
{
    Class temp = objc_getClass("XSCDisassembler");
    void *classData = malloc(class_getInstanceSize(temp));
    id test = class_createInstance(temp, 0);
    return NSApplicationMain(argc, argv);
}
