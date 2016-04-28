
//
//  RSVM.m
//  cocoavm
//
//  Created by Greg Slomin on 8/10/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import "RSVM.h"
#import "Operation.h"
#import "XSCDisassembler.h"
#import "XSCFile.h"
uint32_t jenkins_one_at_a_time_hash(char *key, size_t len)
{
    uint32_t hash, i;
    for(hash = i = 0; i < len; ++i)
    {
        hash += key[i];
        hash += (hash << 10);
        hash ^= (hash >> 6);
    }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    return hash;
}
@implementation StaticAddress
-(NSString*)description
{
    return [NSString stringWithFormat:@"&Statics[%@]", self.slot];
}
-(id)copyWithZone:(NSZone *)zone {
    StaticAddress *another = [[StaticAddress alloc] init];
    //another.address = self.address;
    another.slot = self.slot;
    another.sourceInstr = self.sourceInstr;
    
    return another;
}
@end

@implementation GlobalAddress
-(NSString*)description
{
    return self.string;//[NSString stringWithFormat:@"&Global[%@]", self.slot];
}
-(id)copyWithZone:(NSZone *)zone {
    GlobalAddress *another = [[GlobalAddress alloc] init];
    another.address = self.address;
    another.slot = self.slot;
    another.string = [self.string mutableCopy];
    return another;
}

-(NSDictionary*)serialize {
    return @{@"address":@((uint64_t)self.address), @"slot":self.slot, @"string":[self.string copy]};
}
@end

@implementation FrameAddress
-(NSString*)description
{
    return [NSString stringWithFormat:@"&FP[%@]", self.slot];
}

-(id)copyWithZone:(NSZone *)zone
{
    FrameAddress *another = [[FrameAddress alloc] init];
    another.address = self.address;
    another.slot = self.slot;
    another.sourceInstr = self.sourceInstr;
    
    return another;
}
@end

@implementation StringPointer
-(id)initWithInstr:(Instr*)instruction andStringIndex:(UInt32)index
{
    self = [self init];
    if(self) {
    self.sourceInstr = instruction;
    self.slot = @(index);
    Byte *table = self.sourceInstr.basic_block.thread.xscFile->strings->data;
        self.string = (char*)(&(table[index]));
    }
    self.size = strlen(self.string)+1;
    return self;
    
}

-(id)copyWithZone:(NSZone *)zone
{
    StringPointer *another = [[StringPointer alloc] init];
    another.size = self.size;
    another.string = new char[another.size ];
    
    strcpy(another.string, self.string);
    return another;
}


-(NSString*)description
{
    return [NSString stringWithCString:self.string encoding:NSUTF8StringEncoding];
}
-(int)intValue
{
    return (self.string[0] == 0) ? 0 : (long long)self.string;
}
@end
@implementation  RSStack
-(id)init
{
    self = [super init];
    if(self)
    {
        self.internalStack = [[NSMutableArray alloc] init];
    }
    return self;
}
-(void)push:(id)object
{
    
    if(object == nil)
        [self.internalStack addObject:@0];
    else
        [self.internalStack addObject:object];
}
-(id)peek
{
    return self.internalStack.lastObject;
}
-(id)pop
{
    
    id obj = self.internalStack.lastObject;
    [self.internalStack removeLastObject];
    return obj;
}
-(NSUInteger)count
{
    return [self.internalStack count];
}
@end
@implementation RSVM
-(void)registerNative:(NSString*)name selector:(SEL)callback sender:(id)sender
{
    UInt64 hash = [RSVM hash:name];
    NSLog(@"%x", hash);
    NSNumber *key = [XSCDisassembler getHashFromJoaat:@(hash) usingTranslationTables:[XSCDisassembler tables]];
    if(key)
        [self.realNatives setObject:NSStringFromSelector(callback) forKey:key];
    else
        [self.realNatives setObject:NSStringFromSelector(callback) forKey:@(hash)];
    [self.realNatives setObject:sender forKey:NSStringFromSelector(callback)];
    
}

-(void)registerUnknownNative:(UInt64)hash selector:(SEL)callback sender:(id)sender
{
    NSNumber *key = [XSCDisassembler getHashFromJoaat:@(hash) usingTranslationTables:[XSCDisassembler tables]];
    
    if(key)
        [self.realNatives setObject:NSStringFromSelector(callback) forKey:key];
    else
        [self.realNatives setObject:NSStringFromSelector(callback) forKey:@(hash)];
    [self.realNatives setObject:sender forKey:NSStringFromSelector(callback)];
}
+(UInt32)hash:(NSString *)source
{
    char str[256];
    strcpy(str, source.UTF8String);
    uint32_t hash = jenkins_one_at_a_time_hash(str, source.length);

    return hash;
}
+(instancetype)sharedInstance
{
    static RSVM* vm = nil;
    if(vm == nil)
    {
        vm = [[RSVM alloc] init];
    }
    return vm;
}
-(void)setStartupScript:(NSData*)data withExtension:(NSString*)extension
{
    self.main = [[VMThread alloc] initWithScriptData:data withExtension:extension];
}
-(NSNumber*)getGlobal:(int)index
{
    return @(self.globals[index]);
}
-(NSNumber*)getGlobalPointer:(int)index
{
    Byte *globalPtr = &(self.globals[index]);
    return @((long)globalPtr);
}

-(id)init
{
    self = [super init];
    if(self)
    {
        self.realNatives = [[NSMutableDictionary alloc] init];
        self.heap = [[VMHeap alloc] initWithSize:1024*1024*60];
        //[self opcodeTable];
    }
    return self;
}

+(NSArray*)opcodes
{
    static NSArray *op = nil;
    if(op == nil)
    {
        op = [RSVM generateOpcodeTable];
    }
    return op;
}
+(NSArray*)generateOpcodeTable
{
    NSMutableArray *table = [[NSMutableArray alloc] initWithCapacity:128];
    
    
    for(int i=0; i<127; i++)
    {
        switch(i)
        {
            case 6:
                [table addObject:[INot class]];
                break;
            case 7:
                [table addObject:[INeg class]];
                break;
            case 19:
                [table addObject:[FNeg class]];
                break;
            case 0:
                [table addObject:[Instr class]];
                break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 8:
            case 9:
            case 10:
            case 11:
            case 12:
            case 13:
                [table addObject:[IntTwoArgArithInstr class]];
                break;
            case 14:
            case 15:
            case 16:
            case 17:
            case 18:
            case 20:
            case 21:
            case 22:
            case 23:
            case 24:
            case 25:
                [table addObject:[FloatTwoArgArithInstr class]];
                break;
            case 26:
            case 27:
            case 28:
            case 29:
            case 30:
                [table addObject:[Instr class]];
                break;
            case 31:
            case 32:
            case 33:
                [table addObject:[IntTwoArgArithInstr class]];
                break;
            case 34:
                [table addObject:[OneStackIArg class]];
                break;
            case 35:
            case 36:
                [table addObject:[Instr class]];
                break;
            case 37:
                [table addObject:[PushI8 class]];
                break;
            case 38:
                [table addObject:[PushI88 class]];
                break;
            case 39:
                [table addObject:[PushI888 class]];
                break;
            case 40:
                [table addObject:[PushI32 class]];
                break;
            case 41:
                [table addObject:[PushF32 class]];
                break;
            case 42:
                [table addObject:[Dup class]];
                break;
            case 43:
                [table addObject:[PopStack class]];
                break;
            case 44:
                [table addObject:[CallNative class]];
                break;
            case 45:
                [table addObject:[EntryPointInstr class]];
                break;
            case 46:
                [table addObject:[ReturnInstr class]];
                break;
            case 47:
            case 49:
                [table addObject:[PushInstr class]];
                break;
            case 48:
                [table addObject:[SetPointer class]];
                break;
            case 50:
                [table addObject:[ArrayToStack class]];
                break;
            case 51:
                [table addObject:[ArrayFromStack class]];
                break;
            case 52:
            case 53:
            case 54:
            case 55:
            case 56:
            case 57:
                [table addObject:[I8ImmInstr class]];
                break;
            case 58:
                [table addObject:[StackGetP class]];
                break;
            case 59:
                [table addObject:[StaticGet class]];
                break;
            case 60:
                [table addObject:[StaticSet class]];
                break;
            case 61:
                [table addObject:[IAddImm8 class]];
                break;
            case 62:
                [table addObject:[IMulImm8 class]];
                break;
            case 63:
                [table addObject:[Instr class]];
                break;
            case 64:
            case 65:
            case 66:
                [table addObject:[I8ImmInstr class]];
                break;
            case 67:
                [table addObject:[PushI16 class]];
                break;
            case 68:
                [table addObject:[IAddImm16 class]];
                break;
            case 69:
                [table addObject:[IMulImm16 class]];
                break;
            case 70:
                [table addObject:[I16ImmInstr class]];
                break;
            case 71:
            case 72:
            case 73:
            case 74:
            case 75:
            case 76:
            case 77:
            case 78:
                [table addObject:[I16ImmInstr class]];
                break;
                
            case 79:
                [table addObject:[I16ImmInstr class]];
                break;
            case 80:
            case 81:
                [table addObject:[I16ImmInstr class]];
                break;
            case 82:
                [table addObject:[PGlobal2 class]];
                break;
            case 83:
                [table addObject:[I16ImmInstr class]];
                break;
            case 84:
                [table addObject:[GlobalSet2 class]];
                break;
            case 85:
            case 86:
            case 87:
            case 88:
            case 89:
            case 90:
            case 91:
            case 92:
                [table addObject:[Jump class]];
                break;
            case 93:
                [table addObject:[Call class]];
                break;
            case 94:
                [table addObject:[PGlobal3 class]];
                break;
            case 95:
                [table addObject:[Imm24Instr class]];
                break;
            case 96:
                [table addObject:[GlobalSet3 class]];
                break;
            case 97:
                [table addObject:[Push24Imm class]];
                break;
            case 98:
                [table addObject:[Switch class]];
                break;
            case 99:
                [table addObject:[PushString class]];
                break;
            case 100:
                [table addObject:[PushInstr class]];
                break;
            case 101:
                [table addObject:[SCpy class]];
                break;
            case 102:
            case 103:
            case 104:
                [table addObject:[I8ImmInstr class]];
                break;
            case 105:
            case 106:
            case 107:
                [table addObject:[Instr class]];
                break;
            case 108:
                [table addObject:[PCall class]];
                break;
            case 109:
            case 110:
            case 111:
            case 112:
            case 113:
            case 114:
            case 115:
            case 116:
            case 117:
            case 118:
            case 119:
            case 120:
            case 121:
            case 122:
            case 123:
            case 124:
            case 125:
            case 126:
                [table addObject:[PushInstr class]];
                break;
            default:
                [table addObject:[Instr class]];
        }
    }
    return [table copy];
}

@end
@implementation MallocBlock

@end
@implementation VMHeap

-(void*)addressWithOffset:(void *)offset
{
    void *base = self.baseAddress;
    
    void *result = (void*)((long long)base + (long long)offset);
    return result;
}
-(id)initWithSize:(NSUInteger)heapSize
{
    self = [self init];
    if(self) {
        self.heapSize = heapSize;
        
        self.heap = malloc(heapSize);
        self.baseAddress = (void*)((long long)self.heap & 0xFFFFFFFF00000000);
        self.allocations = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void*)malloc:(NSUInteger)size
{
    if(self.allocations.count == 0)
    {
        MallocBlock *block = [[MallocBlock alloc] init];
        [block setLocation:self.heap];
        [block setSize:size];
        [self.allocations addObject:block];
        return block.location;
    }
    else
    {
        MallocBlock *lastAlloc = [self.allocations lastObject];
        MallocBlock *newAlloc = [[MallocBlock alloc] init];
        [newAlloc setLocation:((char*)lastAlloc.location)+lastAlloc.size];
        [newAlloc setSize:size];
        [self.allocations addObject:newAlloc];
        return newAlloc.location;
    }
}
@end

@implementation ReturnAddress
-(NSString*)description
{
    return [NSString stringWithFormat:@"Return %d", self.destOffset];
}

-(int)intValue {
    return 0;
}
@end

@implementation VMThread
-(NSUInteger)getRealIndexFromFrameOffset:(NSUInteger)frameIndex
{
    NSUInteger offset = ((self.framePointer) -1)-frameIndex;
    if(offset>=self.stack.count)
    {
        NSLog(@"bad offset");
    }
    return offset;
}

-(id)initWithScriptData:(NSData*)data withExtension:(NSString*)extension
{
    self = [super init];
    if(self)
    {
        XSCDisassembler *disassembler = [[XSCDisassembler alloc] init];
        self.vm = [RSVM sharedInstance];
        self.currentIndex = 0;
        self.stack = [[RSStack alloc] init];
        self.statics = [NSMutableArray array];
        self.pc = 0;
        self.callStack = [[RSStack alloc] init];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"nativesReturned" object:nil queue:nil usingBlock:^(NSNotification *note) {
            
            NSDictionary *vals = note.userInfo;
            NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
            [f setNumberStyle:NSNumberFormatterDecimalStyle];
            if(vals.allKeys.count == 1)
            {
                NSString *ret = vals[@"retVal"];
                [[self stack] push:[f numberFromString:ret]];
            }
            else if(vals.allKeys.count == 3)
            {
                NSString *ret = vals[@"retVal1"];
                [[self stack] push:[f numberFromString:ret]];
                NSString *ret2 = vals[@"retVal2"];
                [[self stack] push:[f numberFromString:ret2]];
                NSString *ret3 = vals[@"retVal3"];
                [[self stack] push:[f numberFromString:ret3]];
                
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"updateFields" object:nil];
            
        }];

        
        Byte *bytes = (Byte*)malloc([data length]);
        [data getBytes:bytes];
        if([extension isEqualToString:@"ysc"] || [extension isEqualToString:@"YSC"])
            self.xscFile = new YSCFile();
        else
            self.xscFile = new XSCFile();
        self.xscFile->loadData(bytes, disassembler);
        NSUInteger staticsCount = self.xscFile->statics_count;
        NSMutableArray *statics = [[NSMutableArray alloc] initWithCapacity:staticsCount];
        for(int i=0; i<staticsCount; i++)
        {
            NSUInteger val = self.xscFile->statics[i];
            [statics addObject:[NSNumber numberWithUnsignedInteger:val]];
        }
        self.statics = statics;
        if(self.xscFile->globals_count != 0)
        {
            self.vm.globals = self.xscFile->globals->data;
        }
        disassembler.xscFile = self.xscFile;
        self.disAsm = [disassembler disassemble:self];
        NSArray *basic_blocks = self.disAsm[@"blocks"];
           self.current_blocks = basic_blocks;
           self.currentBlock = basic_blocks.firstObject;
           self.currentInstruction = self.currentBlock.instructions.firstObject;
        [self.currentInstruction execute:self.vm];
        
           self.currentIndex = 0;
//        [self.stack push:@(0)];
//        [self.stack push:@(0)];
        
    }
    return self;
}
-(void)jumpToOffset:(UInt32)offset
{
    __block bool found =false;
    NSUInteger index = 0;
    for(BasicBlock *b in self.current_blocks)
    {
        
 
            for(Instr *i in b.instructions)
            {
                if(i.offset == offset)
                {
                    self.currentInstruction = i;
                    self.currentBlock = b;
                    self.currentIndex = index;
                    [self.currentInstruction execute:self.vm];
                    return;
                }
                index++;
            }
        
    }
   
}
-(void)step
{
    NSUInteger index = [[self.currentBlock instructions] indexOfObject:self.currentInstruction];
    if((index+1) == self.currentBlock.instructions.count)
    {
        index = [self.current_blocks indexOfObject:self.currentBlock];
        if(index != self.current_blocks.count-1)
        {
            self.currentBlock = self.current_blocks[index+1];
            self.currentInstruction = [self.currentBlock.instructions firstObject];
            self.currentIndex = 0;
        } else {
            NSLog(@"Program end");
        }
    }
    else
    {
        self.currentInstruction = [self.currentBlock instructions][index+1];
    }
    [self.currentInstruction execute:self.vm];
}
-(void)runToOffset:(UInt32)offset
{
    static long maxStack = 0;
    ScriptFunction *main = (ScriptFunction*)self.functions.firstObject;
    while(true) {
        NSUInteger index = [[self.currentBlock instructions] indexOfObject:self.currentInstruction];
        
        if((index+1) == self.currentBlock.instructions.count)
        {
            index = [self.current_blocks indexOfObject:self.currentBlock];
            if(index != self.current_blocks.count-1)
            {
                self.currentBlock = self.current_blocks[index+1];
                self.currentInstruction = [self.currentBlock.instructions firstObject];
                self.currentIndex = 0;
            } else {
                NSLog(@"Program end");
                return;
            }
        }
        else
        {
            self.currentInstruction = [self.currentBlock instructions][index+1];
        }
        if([self.currentInstruction isKindOfClass:[ReturnInstr class]]) {
            if([main.basic_blocks containsObject:self.currentInstruction.basic_block] ) {
                NSLog(@"Program finished");
                return;
            }
        }
        if(maxStack < self.currentBlock.thread.stack.internalStack.count)
        {
            maxStack = self.currentBlock.thread.stack.internalStack.count;
            NSLog(@"MaxStack: %d", maxStack);
        }
        [self.currentInstruction execute:self.vm];
        if([self.currentInstruction offset] == offset || self.vm.main.stack.internalStack.count == 0)
            break;
        
    }
}

@end

