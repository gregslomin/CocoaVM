//
//  XSCDisassembler.h
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XSCFile.h"
#include <utility>
@class RSVM;
@class VMThread;
@interface XSCDisassembler : NSObject

@property (nonatomic, assign) XSCFile *xscFile;
+(NSDictionary*)natives;
+(NSString*)getHashKey:(NSString*)orig usingTranslationTables:(NSArray*)tables;
+(NSNumber*)getHashFromJoaat:(NSNumber*)key usingTranslationTables:(NSArray*)tables;
+(NSArray*)tables;
//@property (nonatomic, retain) RSVM *vm;
//+(instancetype)sharedInstance;
//-(id)loadData:(NSData*)data usingRCS7:(BOOL)isRCS7;
-(NSDictionary*)disassemble:(VMThread*)thread;
@end
