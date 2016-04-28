//
//  Operation.h
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

@class RSVM;

typedef enum Arith { ADD, SUBTRACT, MULTIPLY, DIVIDE, MODULUS, CMPEQ, CMPNE, CMPGT, CMPGE, CMPLT, CMPLE, BIT_AND, BIT_OR, BIT_XOR, NO_ARITH, NOT_ZERO } Arithmatic;

@protocol VMInterface <NSObject>

-(void)execute:(RSVM*)vm;
-(id)initWithBytes:(Byte*)bytes;
@end

@class FoldedStringPush;



@class Instr;
@class BasicBlock;
@class VMThread;
@interface Leader : NSObject
@property (nonatomic, retain) NSMutableArray *ins;
@property (nonatomic, retain) NSMutableArray *outs;
@property (nonatomic, assign)int offset;
@end

@interface Instr : NSObject <VMInterface>
@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) UInt32 size;
@property (nonatomic, assign) UInt32 opcode;
@property (nonatomic, assign) UInt32 offset;
@property (nonatomic, retain) BasicBlock *basic_block;
-(id)initWithName:(NSString*)name size:(UInt32)size andOpcode:(UInt32)opcode;
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
-(void)execute:(RSVM*)vm;
@end

@class ScriptFunction;

@interface BasicBlock : NSObject
@property (nonatomic, retain) NSMutableArray *ins;
@property (nonatomic, retain) NSMutableArray *instructions;
@property (nonatomic, retain) NSMutableArray *outs;
@property (nonatomic, retain) ScriptFunction *function;
@property (nonatomic, assign) NSUInteger offsetStart;
@property (nonatomic, assign) NSUInteger offsetEnd;
@property (nonatomic, retain) VMThread *thread;
@property (nonatomic, retain) NSDictionary *offsetMap;
@end

@interface ScriptFunction : NSObject
@property (nonatomic, retain) NSMutableArray *basic_blocks;
@end

@interface FoldedInstr : Instr
@property (nonatomic, retain) NSArray *foldedInstructions;
@end

@interface FoldedSetStatic : FoldedInstr
@property (nonatomic, retain) NSString *description;
-(id)initWithPush:(Instr*)pushInstr andSetLocal:(Instr*)setLocal;
-(id)initWithNative:(Instr*)native andSetLocal:(Instr*)setLocal;
-(id)initWithFoldedStringPush:(FoldedStringPush*)push andSetLocal:(Instr*)setLocal;
@end

@interface FoldedGetLocal : FoldedInstr
-(id)initWithPush:(Instr*)pushInstr andGetLocal:(Instr*)getLocal;
@end



@interface PushInstr : Instr
@property (nonatomic, retain) NSNumber *pushValue;
-(id)initWithName:(NSString *)name size:(UInt32)size opcode:(UInt32)opcode andValue:(NSNumber*)value;
-(void)execute:(RSVM*)vm;
@end

@interface I8ImmInstr : Instr
@property (nonatomic, assign) Byte imm;
@end

@interface PushI8 : PushInstr

@end

@interface PushI88 : I8ImmInstr
@property (nonatomic, assign) Byte imm2;
@end
@interface PushI888 : I8ImmInstr
@property (nonatomic, assign) Byte imm2;
@property (nonatomic, assign) Byte imm3;
@end


@interface PushString : Instr
@end
@interface FoldedStringPush : FoldedInstr
@property (nonatomic, assign) UInt32 stringIndex;
@property (nonatomic, retain) NSString *string;
-(id)initWithPush:(PushInstr*)val andStringPush:(PushString*)pushString withStringTable:(Byte*)strings;
@end

@interface PushF32 : PushInstr

@property (nonatomic, assign) float imm;
@end

@interface PushI32 : PushInstr
@property (nonatomic, assign) UInt32 imm;
@end

@interface I16ImmInstr : Instr
@property (nonatomic, assign) UInt16 imm;
@end
@interface PushI16 : PushInstr
@property (nonatomic, assign) UInt16 imm;
@end
@interface Jump : Instr
@property (nonatomic, assign) SInt16 imm;
@property (nonatomic, assign) Arithmatic type;
@property (retain, nonatomic) Instr *jumpTarget;
-(UInt32)jumpOffset;
@end
@interface StackGetP : I8ImmInstr
@end
@interface SetPointer : Instr
@end
@interface StaticSet : I8ImmInstr

@end

@interface StaticGet : I8ImmInstr

@end
@interface OneStackIArg : Instr

@end

@interface TwoStackIArg : Instr
@end

@interface OneStackFArg : Instr
@end

@interface TwoStackFArg : Instr
@end



@interface IntTwoArgArithInstr : TwoStackIArg
@property (nonatomic, assign) Arithmatic type;
-(id)initWithName:(NSString *)name size:(UInt32)size opcode:(UInt32)opcode andType:(Arithmatic)type;
@end

@interface FloatTwoArgArithInstr : TwoStackFArg
@property (nonatomic, assign) Arithmatic type;
-(NSString*)sign;
-(NSNumber*)calculateWithFirst:(NSNumber*)firstvalue andSecond:(NSNumber*)secondValue;
-(id)initWithName:(NSString *)name size:(UInt32)size opcode:(UInt32)opcode andType:(Arithmatic)type;
@end

@interface EntryPointInstr : Instr
@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) int localCount;
@property (nonatomic, assign) int paramCount;
-(id)initWithName:(NSString *)name size:(UInt32)size andOpcode:(UInt32)opcode;
-(void)execute:(RSVM *)vm;
@end

@interface ReturnInstr : I16ImmInstr
@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) Byte returnCount;
@property (nonatomic, assign) Byte paramCount;
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@end

@interface CallNative : Instr
@property (nonatomic, assign) UInt64 native;
@property (nonatomic, assign) Byte paramCount;
@property (nonatomic, assign) Byte retFlag;
@property (nonatomic, assign) UInt64 hash;
-(void)execute:(RSVM *)vm;
@end

@interface Call : Instr
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@property (nonatomic, assign) UInt32 callOffset;
@property (nonatomic, assign) UInt32 paramCount;
@property (nonatomic, assign) UInt32 returnCount;
@end

@interface Dup: Instr
@end

@interface PCall: Instr
@end

@interface INot : Instr
@end
@interface INeg :Instr
@end

@interface FNeg :Instr
@end


@interface Switch : Instr
@property (nonatomic, retain) NSArray *cases;
@end

@interface Imm24Instr : Instr
@property (nonatomic, assign) UInt32 imm;
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@end

@interface Push24Imm : PushInstr
@property (nonatomic, assign) UInt32 imm;
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@end
@interface PGlobal3 : Imm24Instr
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@end

@interface PGlobal2 : I16ImmInstr
@end

@interface PopStack : Instr
@end

@interface IAddImm8 : OneStackIArg
@property (nonatomic, assign) Byte imm;
@end
@interface IMulImm8 : OneStackIArg
@property (nonatomic, assign) Byte imm;
@end

@interface IAddImm16 : OneStackIArg
@property (nonatomic, assign) Byte imm;
@end
@interface IMulImm16 : OneStackIArg
@property (nonatomic, assign) Byte imm;
@end

@interface ArrayFromStack : Instr
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@end
@interface ArrayToStack : Instr
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread;
@end

@interface FoldedArrayFromStack : FoldedInstr
-(id)initWithFromStack:(ArrayFromStack*)fromStack getPointer:(StackGetP*)getPointer numValues:(PushInstr*)numValues andPushValues:(NSArray*)values;
@end

@interface FoldedTwoArgFloatArith : PushInstr
@property (nonatomic, retain) NSNumber *result;
@property (nonatomic, retain) NSArray *foldedInstructions;
-(id)initWithArith:(FloatTwoArgArithInstr*)arith usingFirstPush:(PushInstr*)first andSecondPush:(PushInstr*)second;
@end

@interface GlobalSet2 : I16ImmInstr
@end

@interface GlobalSet3 : Imm24Instr
@end

@interface FoldedNative : FoldedInstr
@property (nonatomic, assign) UInt32 native;
@property (nonatomic, assign) Byte paramCount;
@property (nonatomic, assign) Byte retFlag;
-(id)initWithNative:(CallNative*)native params:(NSArray*)params;
@end

@interface FoldedGlobalSet : FoldedInstr
@property (nonatomic, retain) NSNumber *pushValue;
-(id)initWithGlobalSet:(GlobalSet2*)globalSet andPush:(PushInstr*)push;
-(id)initWithGlobalSet3:(GlobalSet3*)globalSet andPush:(PushInstr*)push;
-(id)initWithGlobalSet3:(GlobalSet3*)globalSet andGlobalGet2:(I16ImmInstr*)push;
-(id)initWithGlobalSet3:(GlobalSet3*)globalSet andGlobalGet3:(Imm24Instr*)push;
@end
@interface SCpy : I8ImmInstr    

@end
@interface FoldedSCpy : FoldedInstr
-(id)initWithSCpy:(Instr*)scpy stackPointer:(StackGetP*)global andFoldedStringPush:(FoldedStringPush*)foldedStringPush;
-(id)initWithSCpy:(Instr*)scpy globalPointer3:(PGlobal3*)global andFoldedStringPush:(FoldedStringPush*)foldedStringPush;
-(id)initWithSCpy:(Instr*)scpy globalPointer2:(PGlobal2*)global andFoldedStringPush:(FoldedStringPush*)foldedStringPush;
@end

@interface FoldedCall : FoldedInstr
-(id)initWithCall:(Call*)call;
@end

@interface FoldedGetAddressImmediate : FoldedInstr
-(id)initWithGetArrayP:(I8ImmInstr*)getparray;
@end