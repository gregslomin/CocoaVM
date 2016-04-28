//
//  RSVM.h
//  cocoavm
//
//  Created by Greg Slomin on 8/10/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XSCFile.h"

@class Instr;
@class BasicBlock;
@class VMThread;
@interface RSStack : NSObject
@property (nonatomic, retain) NSMutableArray *internalStack;
-(void)push:(id)object;
-(id)pop;
-(id)peek;
-(NSUInteger)count;
@end

@interface FrameAddress : NSObject
@property (nonatomic, assign) id address;
@property (nonatomic, assign) NSNumber *slot;
@property (nonatomic, retain) Instr *sourceInstr;
@end

@interface ReturnAddress : NSObject
@property (nonatomic, retain) Instr *sourceInstr;
@property (nonatomic, assign) UInt32 destOffset;
@property (nonatomic, assign) NSUInteger frameAddress;

@end
@interface GlobalAddress : NSObject
@property (nonatomic, assign) void* address;
@property (nonatomic, assign) NSNumber *slot;
@property (nonatomic, retain) NSMutableString *string;
-(NSDictionary*)serialize;
//@property (nonatomic, retain) Instr *sourceInstr;
@end
@interface StaticAddress : NSObject
@property (nonatomic, assign) NSNumber *slot;
@property (nonatomic, retain) Instr *sourceInstr;
@end

@interface StringPointer : NSObject
@property (nonatomic, assign) NSNumber *slot;
@property (nonatomic, retain) Instr *sourceInstr;
@property (nonatomic, assign) char* string;
@property (nonatomic, assign) uint32_t size;
-(id)initWithInstr:(Instr*)instruction andStringIndex:(UInt32)index;
-(int)intValue;
@end

@interface MallocBlock : NSObject
@property (nonatomic, assign) void* location;
@property (nonatomic, assign) NSUInteger size;
@end
@interface VMHeap : NSObject
-(id)initWithSize:(NSUInteger)heapSize;
-(void*)malloc:(NSUInteger)size;
-(void*)free:(void*)block;
-(void*)addressWithOffset:(void*)offset;
@property (nonatomic, assign) void* baseAddress;
@property (nonatomic, assign) void* heap;
@property (nonatomic, assign) NSUInteger heapSize;
@property (nonatomic, retain) NSMutableArray *allocations;
@end




@interface RSVM : NSObject

@property (nonatomic, retain) VMHeap *heap;
@property (nonatomic, retain) NSArray *opcodeTable;
@property (nonatomic, retain) VMThread *main;
@property (nonatomic, assign) Byte *globals;
@property (nonatomic, retain) NSMutableDictionary *realNatives;
-(void)registerNative:(NSString*)name selector:(SEL)callback sender:(id)sender;
-(void)registerUnknownNative:(UInt32)hash selector:(SEL)callback sender:(id)sender;
+(instancetype)sharedInstance;
-(NSNumber*)getGlobal:(int)index;
-(NSNumber*)getGlobalPointer:(int)index;
+(NSArray*)opcodes;
-(void)setStartupScript:(NSData*)data withExtension:(NSString*)extension;
+(UInt32)hash:(NSString*)source;
@end

@interface VMThread : NSObject

@property (nonatomic, retain) NSArray *functions;
@property (nonatomic, assign) NSUInteger currentIndex;
@property (nonatomic, retain) Instr* currentInstruction;
@property (nonatomic, retain) BasicBlock* currentBlock;
@property (nonatomic, retain) NSArray *current_blocks;
@property (nonatomic, retain) RSStack *stack;
@property (nonatomic, retain) NSMutableArray *statics;
@property (nonatomic, assign) NSUInteger pc;

@property (nonatomic, retain) RSVM *vm;
@property (nonatomic, assign) XSCFile *xscFile;
@property (nonatomic, retain) NSDictionary *disAsm;
@property (nonatomic, retain) RSStack *callStack;
@property (nonatomic, assign) NSUInteger framePointer;
-(id)initWithScriptData:(NSData*)data withExtension:(NSString*)extension;
-(void)step;
-(void)jumpToOffset:(UInt32)offset;
-(void)runToOffset:(UInt32)offset;
-(NSUInteger)getRealIndexFromFrameOffset:(NSUInteger)frameIndex;
@end
