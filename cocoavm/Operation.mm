//
//  Operation.cpp
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#include "Operation.h"
#include "RSVM.h"
#include "XSCDisassembler.h"
#define CFSwapInt32(x) (x);
#define CFSwapInt16(x) (x);
@implementation BasicBlock
-(id)init
{
    self = [super init];
    if (self)
    {
        self.ins = [[NSMutableArray alloc] init];
        self.outs = [[NSMutableArray alloc] init];
        self.instructions = [[NSMutableArray alloc] init];
        
    }
    return self;
}
@end
@implementation ArrayToStack

-(id)initWithBytes:(Byte *)bytes thread:(VMThread *)thread
{
    self = [super initWithBytes:bytes thread:thread];
    if(self)
    {
        
    }
    return self;
}
-(void)execute:(RSVM *)vm
{
    id address = [self.basic_block.thread.stack pop];
    NSNumber *count = [self.basic_block.thread.stack pop];
    if([address isKindOfClass:[FrameAddress class]])
    {
        for(int i=0; i<count.intValue; i++)
        {
//            ([address slot].intValue) - i
            int index = [self.basic_block.thread getRealIndexFromFrameOffset:[address slot].intValue+i];
            id obj = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            [self.basic_block.thread.stack push:[obj copy]];
        }
    } else if([address isKindOfClass:[StaticAddress class]]) {
        StaticAddress *addr = [address copy];
        for(int i=0; i<count.intValue; i++)
        {
            //            ([address slot].intValue) - i
//            int index = [self.basic_block.thread getRealIndexFromFrameOffset:[address slot].intValue+i];
            id obj = self.basic_block.thread.statics[addr.slot.intValue+i];
            [self.basic_block.thread.stack push:obj];
        }
    } else if([address isKindOfClass:[GlobalAddress class]]) {
        GlobalAddress *addr = [address copy];
        uint64_t *obj = (uint64_t*)&(self.basic_block.thread.xscFile->globals->data[addr.slot.intValue]);
        for(int i=0; i<count.intValue; i++)
        {
            //            ([address slot].intValue) - i
            //            int index = [self.basic_block.thread getRealIndexFromFrameOffset:[address slot].intValue+i];

            [self.basic_block.thread.stack push:@(obj[i])];
        }
    } else {
        [super execute:vm];
    }
}
@end
@implementation Leader
-(id)init
{
    self = [super init];
    if(self)
    {
        self.ins = [[NSMutableArray alloc] init];
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"Offset: %d", self.offset];
}
@end

@implementation ScriptFunction

@end



@implementation Instr
-(id)initWithName:(NSString *)name size:(UInt32)size andOpcode:(UInt32)opcode
{
    
    if(self)
    {
    self.name = name;
    self.size = size;
    self.opcode = opcode;
    }
    return self;
   
}
-(void)execute:(RSVM *)vm
{
    if(self.opcode == 50) {
        //id address = [self.basic_block.thread.stack pop];
        
    } else if(self.opcode == 26) {
        NSMutableArray *lhs = [[NSMutableArray alloc] init];
        NSMutableArray *rhs = [[NSMutableArray alloc] init];
        NSMutableArray *result = [[NSMutableArray alloc] init];
        for(int j=0; j<3; j++) {
            [lhs addObject:[self.basic_block.thread.stack pop]];
        }
        for(int j=0; j<3; j++) {
            [rhs addObject:[self.basic_block.thread.stack pop]];
        }
        
        for(int j=0; j<3; j++) {
            [result addObject:@([((NSNumber*)lhs[j]) floatValue] +[((NSNumber*)rhs[j]) floatValue] ) ];
        }
        
        [result enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [self.basic_block.thread.stack push:obj];
        }];
        return;

    } else if(self.opcode == 105) {
//        NSLog(@"Test");
        id addr = [self.basic_block.thread.stack pop];
        id unk = [self.basic_block.thread.stack pop];
        NSNumber* numPop = [self.basic_block.thread.stack pop];
        NSMutableArray *vals = [[NSMutableArray alloc] init];
        
        if([addr isKindOfClass:[GlobalAddress class]]) {
            
            GlobalAddress *ga = [addr copy];
            for(int i=0; i<numPop.unsignedIntegerValue; i++) {
                [vals addObject:[self.basic_block.thread.stack pop]];
            
            }
            int idx = 0;
            for(int i=numPop.intValue-1; i>=0; i--){
                *((uint64_t*)ga.address+idx*8) = [((NSNumber*)vals[i]) unsignedIntegerValue];
                idx++;
            }
//            for(id val : vals) {
//                *((UInt32*)ga.address+i*8) = [((NSNumber*)val) unsignedIntValue];
//                i++;
//            }
            
        } else if([addr isKindOfClass:[FrameAddress class]]) {
            FrameAddress *fa = addr;
            int fIndex = fa.slot.intValue;
            
            for(int i=0; i<numPop.unsignedIntegerValue; i++) {
                [vals addObject:[self.basic_block.thread.stack pop]];
                
            }
            
            int idx = 0;
            for(int i=numPop.intValue-1; i>=0; i--) {
                NSUInteger realIndex = [self.basic_block.thread getRealIndexFromFrameOffset:fIndex+idx];
                NSNumber *obj = vals[i];

                [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:realIndex withObject:obj];
                idx++;
            }
            

//            for(int i=0; i<vals.count; i++) {
//                //NSUInteger realIndex = [self.basic_block.thread getRealIndexFromFrameOffset:fIndex+i];
//                [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:realIndex withObject:vals[i]];
//            }
        } else {
            NSString *msg = [NSString stringWithFormat:@"Unimplemented Instruction : %@ (%d) - %x", self.name, self.offset, self.offset];
            NSAssert(false, msg);
        }

        return;
    }else if(self.opcode == 0){
        return;
    }
    NSString *msg = [NSString stringWithFormat:@"Unimplemented Instruction : %@ (%d) - %x", self.name, self.offset, self.offset];
    NSAssert(false, msg);
}
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [self init ];//initWithName:@"Instr" size:0 andOpcode:bytes[0]];
    
    if(bytes[0] >= 127)
        bytes[0] = 0;
    
    switch(bytes[0])
    {
        case 0:
            self.name = @"nop";
            self.size= 1;
            self.opcode = 0;
            break;
        case 26:
            self.name = @"vadd";
            self.size= 1;
            self.opcode = 26;
            break;
        case 27:
            self.name = @"vsub";
            self.size= 1;
            self.opcode = 27;
            break;
        case 28:
            self.name = @"vmul";
            self.size= 1;
            self.opcode = 28;
            break;
        case 29:
            self.name = @"vdiv";
            self.size= 1;
            self.opcode = 29;
            break;
        case 30:
            self.name = @"vneg";
            self.size= 1;
            self.opcode = 30;
            break;
        case 35:
            self.name = @"ftoi";
            self.size= 1;
            self.opcode = 35;
            break;
        case 36:
            self.name = @"dup2";
            self.size= 1;
            self.opcode = 36;
            break;
        case 50:
            self.name = @"tostack";
            self.size = 1;
            self.opcode = 50;
            break;
        case 63:
            self.name = @"getstackimmp";
            self.size = 1;
            self.opcode = 63;
            break;
        case 105:
            self.name = @"sncpy";
            self.size = 1;
            self.opcode = 105;
            break;
        case 106:
            self.name = @"catch";
            self.size = 1;
            self.opcode = 106;
            break;
        case 107:
            self.name = @"throw";
            self.size = 1;
            self.opcode = 107;
            break;
        case 108:
            self.name = @"pcall";
            self.size = 1;
            self.opcode = 108;
            break;
    };
    return self;
}
-(NSString*)description
{
    return self.name;
}
@end

@implementation ArrayFromStack

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"ArrayFromStack" size:1 andOpcode:51];
    return self;
}
-(void)execute:(RSVM*)vm
{
    id address = [[self.basic_block.thread stack] pop];
    if([address isKindOfClass:[GlobalAddress class]])
    {
        StaticAddress *staticAddr = [address copy];
        NSUInteger index = [[staticAddr slot] intValue];
        NSUInteger count = [[[self.basic_block.thread stack] pop] intValue];
        Byte *globals = self.basic_block.thread.xscFile->globals->data;//(UInt32*)vm.globals;
        for(int i=0; i<count; i++)
        {
            NSNumber *val = [[self.basic_block.thread stack] pop];
            
            if([val isKindOfClass:[StringPointer class]]) {
                StringPointer *sp = (id)val;
                void **dst = (void**)(&globals[index+((count-1)-i)]);//(char**)globalAddress.address;
                *dst = (void*)(((long long)sp));
                continue;
                
            }
            if(strcmp([val objCType], @encode(float)) == 0)
            {
                float primval = [val floatValue];
                float * temp = (float*)((Byte*)&(globals[index+((count-1)-i)]));
                
                *temp = primval;//*(uint64_t*)((void*)&primval);
            }
            else
            {
                int primval = [val intValue];
                int * temp = (int*)((void*)&(globals[index+((count-1)-i)]));
                
                *temp = primval;//*(uint64_t*)((void*)&primval);
            }
           
        }
    }
    else if([address isKindOfClass:[StaticAddress class]])
    {
        StaticAddress *staticAddr = [address copy];
        NSUInteger index = [[staticAddr slot] intValue];
        NSUInteger count = [[[self.basic_block.thread stack] pop] intValue];
        for(int i=0; i<count; i++)
        {
            self.basic_block.thread.statics[index+((count-1)-i)] = [[self.basic_block.thread stack] pop];
        }
    } else if([address isKindOfClass:[FrameAddress class]]) {
        FrameAddress *addr = [address copy];
        NSUInteger index = [[addr slot] intValue];
        NSUInteger count = [[[self.basic_block.thread stack] pop] intValue];
        for(int i=0; i<count; i++)
        {
            int realIndex = [self.basic_block.thread getRealIndexFromFrameOffset:index+((count-1)-i)];
            [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:realIndex withObject:[[self.basic_block.thread stack] pop]];
        }
    } else {
        [super execute:vm];
    }
}
@end


@implementation PushInstr

-(id)initWithName:(NSString *)name size:(UInt32)size opcode:(UInt32)opcode andValue:(NSNumber *)value
{
    self = [super initWithName:name size:size andOpcode:opcode];
    if(self)
    {
        self.pushValue = value;
    }
    return self;
}

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    if(self)
    {
        NSUInteger opcode = bytes[0];
        switch(opcode)
        {
            case 47:
                self.name = @"getpointer";
                self.size = 1;
                self.opcode = 47;
                self.pushValue = nil;
                break;
            case 48:
                self.name = @"setpointer";
                self.size = 1;
                self.opcode = 48;
                self.pushValue = nil;
                break;
            case 49:
                self.name = @"ppeekset";
                self.size = 1;
                self.opcode = 49;
                self.pushValue = nil;
                break;
            case 100:
                self.name = @"GetHash";
                self.size = 1;
                self.opcode = (UInt32)opcode;
                self.pushValue = @0;
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
            {
                int val = (int)opcode - 110;
                self.name = [NSString stringWithFormat:@"Push %d", val];
                self.pushValue = [NSNumber numberWithInt:val];
                self.size = 1;
                self.opcode = (UInt32)opcode;
                break;
            }
            case 118:
            case 119:
            case 120:
            case 121:
            case 122:
            case 123:
            case 124:
            case 125:
            case 126:
            {
                float val = (float)opcode - 120;
                self.name = [NSString stringWithFormat:@"Push %.f", val];
                self.pushValue = [NSNumber numberWithFloat:val];
                self.size = 1;
                self.opcode = (UInt32)opcode;
                break;
            }
                
        }
    }
    return self;
}

-(void)execute:(RSVM *)vm
{
    if(self.opcode == 49) {
        NSNumber *val = [self.basic_block.thread.stack pop];
        id addr = [self.basic_block.thread.stack.internalStack lastObject];

        if([addr isKindOfClass:[GlobalAddress class]]) {
            uint64_t *address = (uint64_t*)&(vm.globals[((GlobalAddress*)addr).slot.unsignedIntegerValue]);
            *address = (uint64_t)val.unsignedIntegerValue;
            
        } else if([addr isKindOfClass:[FrameAddress class]]) {
            FrameAddress *frameAddr = addr;
            
            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:frameAddr.slot.unsignedIntegerValue];//(self.basic_block.thread.stack.internalStack.count-
            [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:index withObject:val];
            
        }else {
            [super execute:vm];
        }
    }else if(self.opcode == 47) {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]]) {
            GlobalAddress *globalAddr = [address copy];
            uint64_t *val = (uint64_t*)&(self.basic_block.thread.xscFile->globals->data[globalAddr.slot.unsignedIntegerValue]);
            [self.basic_block.thread.stack push:@(*val)];
        } else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *frameAddr = [address copy];

            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:frameAddr.slot.unsignedIntegerValue];//(self.basic_block.thread.stack.internalStack.count-
            id obj = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            [self.basic_block.thread.stack push:obj];
        } else if([address isKindOfClass:[StaticAddress class]]) {
            UInt32 index = ((StaticAddress*)address).slot.unsignedIntValue;//(self.basic_block.thread.stack.internalStack.count-
            id obj = [self.basic_block.thread.statics objectAtIndex:index];
            [self.basic_block.thread.stack push:obj];
        }else {
            [super execute:vm];
        }
    } else {
    [self.basic_block.thread.stack push:self.pushValue];
    }
}
-(NSString*)description
{
    return self.name;
}
@end

@implementation OneStackIArg

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    if(self)
    {
        NSUInteger opcode = bytes[0];
        switch(opcode)
        {
            case 34:
                self.name = @"itof";
                break;
        };
        self.size = 1;
        self.opcode = (UInt32)opcode;
    }
    return self;
}

@end
@implementation TwoStackIArg

@end

@implementation TwoStackFArg


@end
@implementation IntTwoArgArithInstr

-(id)initWithName:(NSString *)name size:(UInt32)size opcode:(UInt32)opcode andType:(Arithmatic)type
{
    self = [super initWithName:name size:size andOpcode:opcode];
    if(self)
    {
        self.type = type;
    }
    return self;
}

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    if(self)
    {
        
    NSUInteger opcode = bytes[0];
        self = [super initWithName:@"IntAirth" size:1 andOpcode:opcode];
    switch(opcode)
    {
        case 1:
            self.type = ADD;
            break;
        case 2:
            self.type = SUBTRACT;
            break;
        case 3:
            self.type = MULTIPLY;
            break;
        case 4:
            self.type = DIVIDE;
            break;
        case 5:
            self.type = MODULUS;
            break;
        case 8:
            self.type = CMPEQ;
            break;
        case 9:
            self.type = CMPNE;
            break;
        case 10:
            self.type = CMPGT;
            break;
        case 11:
            self.type = CMPGE;
            break;
        case 12:
            self.type = CMPLT;
            break;
        case 13:
            self.type = CMPLE;
            break;
        case 31:
            self.type = BIT_AND;
            break;
        case 32:
            self.type = BIT_OR;
            break;
        case 33:
            self.type = BIT_XOR;
            break;
    }
    }
    return self;
}
-(void)execute:(RSVM *)vm
{
    NSNumber *second = [self.basic_block.thread.stack pop];
    NSNumber *first = [self.basic_block.thread.stack pop];

    NSNumber *result = nil;
    
    switch(self.type)
    {
            
        case ADD:
            result = [NSNumber numberWithInt:[first intValue] + [second intValue]];
            break;
        case SUBTRACT:
            result = [NSNumber numberWithInt:[first intValue] - [second intValue]];
            break;
        case DIVIDE:
            if(second.integerValue == 0)
                result = @(0);
            else
                result = [NSNumber numberWithInt:[first intValue] / [second intValue]];
            break;
        case MULTIPLY:
            result = [NSNumber numberWithInt:[first intValue] * [second intValue]];
            break;
        case MODULUS:
            result = [NSNumber numberWithInt:[first intValue] % [second intValue]];
            break;
        case CMPEQ:
            result = ([first intValue] == [second intValue]) ? @YES : @NO;
            break;
        case CMPNE:
            result = ([first intValue] != [second intValue]) ? @YES : @NO;
            break;
        case CMPGT:
            result = ([first intValue] > [second intValue]) ? @YES : @NO;
            break;
        case CMPGE:
            result = ([first intValue] >= [second intValue]) ? @YES : @NO;
            break;
        case CMPLT:
            result = ([first intValue] < [second intValue]) ? @YES : @NO;
            break;
        case CMPLE:
            result = ([first intValue] <= [second intValue]) ? @YES : @NO;
            break;
        case BIT_AND:
            result = [NSNumber numberWithInt:[first intValue] & [second intValue]];
            break;
        case BIT_OR:
            result = [NSNumber numberWithInt:[first intValue] | [second intValue]];
            break;
        case BIT_XOR:
           result = [NSNumber numberWithInt:[first intValue] ^ [second intValue]];
            break;
            
    }
    [self.basic_block.thread.stack push:result];
}

-(NSString*)description
{
    switch(self.opcode)
    {
        case 1:
            return @"iadd";
            break;
        case 2:
            return @"isub";
            break;
        case 3:
            return @"imul";
            break;
        case 4:
            return @"idiv";
            break;
        case 5:
            return @"imod";
            break;
        case 8:
            return @"icmpeq";
            break;
        case 9:
            return @"icmpne";
            break;
        case 10:
            return @"icmpgt";
            break;
        case 11:
            return @"icmpge";
            break;
        case 12:
            return @"icmplt";
            break;
        case 13:
            return @"icmple";
            break;
        case 31:
            return @"and";
            break;
        case 32:
            return @"or";
            break;
        case 33:
            return @"xor";
            break;
    }
    return self.name;
}
@end

@implementation FloatTwoArgArithInstr

-(id)initWithName:(NSString *)name size:(UInt32)size opcode:(UInt32)opcode andType:(Arithmatic)type
{
    self = [super initWithName:name size:size andOpcode:opcode];
    if(self)
    {
        self.type = type;
    }
    return self;
}
-(NSNumber*)calculateWithFirst:(NSNumber*)firstvalue andSecond:(NSNumber*)secondValue
{
    float l = firstvalue.floatValue;
    float r = secondValue.floatValue;
    switch(self.opcode)
    {
        case 14:
            return @(l+r);
            break;
        case 15:
            return @(l-r);
            break;
        case 16:
            return @(l*r);
            break;
        case 17:
            return @(l/r);
            break;
        case 18:
            return @(fmod(l, r));
            break;
        case 20:
            return @(l==r);
            break;
        case 21:
            return @(l!=r);
            break;
        case 22:
            return @(l>r);
            break;
        case 23:
            return @(l>=r);
            break;
        case 24:
            return @(l<r);
            break;
        case 25:
            return @(l<=r);
            break;
            
            
    };
    
    return @0;

}
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    if(self)
    {
        NSUInteger opcode = bytes[0];
        self = [super initWithName:@"FloatAirth" size:1 andOpcode:opcode];
        
        switch(opcode)
        {
            case 14:
                self.type = ADD;
                break;
            case 15:
                self.type = SUBTRACT;
                break;
            case 16:
                self.type = MULTIPLY;
                break;
            case 17:
                self.type = DIVIDE;
                break;
            case 18:
                self.type = MODULUS;
                break;
            case 20:
                self.type = CMPEQ;
                break;
            case 21:
                self.type = CMPNE;
                break;
            case 22:
                self.type = CMPGT;
                break;
            case 23:
                self.type = CMPGE;
                break;
            case 24:
                self.type = CMPLT;
                break;
            case 25:
                self.type = CMPLE;
                break;
           
                
        }
    }
    return self;
}
-(void)execute:(RSVM *)vm
{
    NSNumber *first = [self.basic_block.thread.stack pop];
    NSNumber *second = [self.basic_block.thread.stack pop];
    NSNumber *result = nil;
    switch(self.type)
    {
        case ADD:
            result = [NSNumber numberWithFloat:[first floatValue] + [second floatValue]];
            break;
        case SUBTRACT:
            result = [NSNumber numberWithFloat:[first floatValue] - [second floatValue]];
            break;
        case DIVIDE:
            result = [NSNumber numberWithFloat:[first floatValue] / [second floatValue]];
            break;
        case MULTIPLY:
            result = [NSNumber numberWithFloat:[first floatValue] * [second floatValue]];
            break;
        case MODULUS:
            result = [NSNumber numberWithFloat:(fmod([first floatValue], [second floatValue]))];
            break;
        case CMPEQ:
            result = ([first floatValue] == [second floatValue]) ? @YES : @NO;
            break;
        case CMPNE:
            result = ([first floatValue] != [second floatValue]) ? @YES : @NO;
            break;
        case CMPGT:
            result = ([first floatValue] > [second floatValue]) ? @YES : @NO;
            break;
        case CMPGE:
            result = ([first floatValue] >= [second floatValue]) ? @YES : @NO;
            break;
        case CMPLT:
            result = ([first floatValue] < [second floatValue]) ? @YES : @NO;
            break;
        case CMPLE:
            result = ([first floatValue] <= [second floatValue]) ? @YES : @NO;
            break;
    }
    [self.basic_block.thread.stack push:result];
}

-(NSString*)description
{
    switch(self.opcode)
    {
        case 14:
            return @"fadd";
            break;
        case 15:
            return @"fsub";
            break;
        case 16:
            return @"fmul";
            break;
        case 17:
            return @"fdiv";
            break;
        case 18:
            return @"fmod";
            break;
        case 20:
            return @"fcmpeq";
            break;
        case 21:
            return @"fcmpne";
            break;
        case 22:
            return @"fcmpgt";
            break;
        case 23:
            return @"fcmpge";
            break;
        case 24:
            return @"fcmplt";
            break;
        case 25:
            return @"fcmple";
            break;
            
            
    };
    return self.name;
    
}

-(NSString*)sign
{
    switch(self.opcode)
    {
        case 14:
            return @"+";
            break;
        case 15:
            return @"-";
            break;
        case 16:
            return @"*";
            break;
        case 17:
            return @"/";
            break;
        case 18:
            return @"%";
            break;
        case 20:
            return @"==";
            break;
        case 21:
            return @"!=";
            break;
        case 22:
            return @">";
            break;
        case 23:
            return @">=";
            break;
        case 24:
            return @"<";
            break;
        case 25:
            return @"<=";
            break;
            
            
    };
    return self.name;
    
}
@end
@implementation ReturnInstr

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"Return" size:3 andOpcode:46];
    self.returnCount = bytes[2];
    self.paramCount = bytes[1];
    
    return self;
}
-(void)execute:(RSVM *)vm
{
    if(self.basic_block.thread.stack.internalStack.count == 0)
        return;
    else
    {
                int oldFP = self.basic_block.thread.stack.internalStack.count;
        NSMutableArray *returns = [[NSMutableArray alloc] init];
        for(int i=0; i<self.returnCount; i++) {
            [returns addObject:[self.basic_block.thread.stack pop]];
        }
        
        for(int i=0; i<self.paramCount; i++)
            [self.basic_block.thread.stack pop];
        
        ReturnAddress *offset = [self.basic_block.thread.stack pop];
        EntryPointInstr *entryPoint = [self.basic_block.thread.stack pop];
        if(entryPoint != nil)
        {
            for(int i=0; i<entryPoint.localCount-2; i++)
            {
                [self.basic_block.thread.stack pop];
            }
        }


        if([offset isKindOfClass:[ReturnAddress class]] == NO)
            return;
        
        self.basic_block.thread.framePointer = offset.frameAddress;//oldFP - self.basic_block.thread.stack.internalStack.count;
        NSSet *set = [NSSet setWithArray:self.basic_block.thread.stack.internalStack];
        for(id obj in set) {
            if([obj isKindOfClass:[FrameAddress class]]) {
                FrameAddress *addr = obj;
                addr.slot =  @(addr.slot.integerValue + ( self.basic_block.thread.framePointer - oldFP+1));
            }
        }
        
        [returns enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [self.basic_block.thread.stack push:obj];
        }];
        
        [self.basic_block.thread jumpToOffset:[offset destOffset]];
    }
}
@end
@implementation EntryPointInstr
-(id)initWithName:(NSString *)name size:(UInt32)size andOpcode:(UInt32)opcode
{
    self = [super initWithName:name size:size andOpcode:opcode];
    if(self)
    {
        
    }
    return self;
}


-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 45)
    {
        UInt32 operation = ((UInt32*)bytes)[0];
        UInt32 nameLen = bytes[4]; 
        self = [super initWithName:@"Enter" size:5+nameLen andOpcode:45];
        self.paramCount = (uint8_t)bytes[1];
        UInt16 *temp = (UInt16*)&bytes[2];
        self.localCount = CFSwapInt16(*temp);
    }
    self.name = [self.name stringByAppendingFormat:@" Locals: %d Params: %d", self.localCount, self.paramCount];
    return self;
}
-(void)execute:(RSVM *)vm
{

            ReturnAddress *ret = [self.basic_block.thread.stack pop];
    ret.frameAddress  =self.basic_block.thread.framePointer;
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    for(int i=0; i<self.paramCount; i++)
    {
        [arr addObject:[self.basic_block.thread.stack pop]];
    }
    
    
    for(int i=0; i<self.localCount-2; i++)
        [self.basic_block.thread.stack push:@(0)];

    [self.basic_block.thread.callStack push:self];
        [self.basic_block.thread.stack push:self];
    [self.basic_block.thread.stack push:ret];




    
    
    [arr enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.basic_block.thread.stack push:obj];
    }];
    int oldFP = self.basic_block.thread.framePointer;
    self.basic_block.thread.framePointer = self.basic_block.thread.stack.internalStack.count;
    int sub = self.basic_block.thread.framePointer - oldFP;
 
    NSSet *set = [NSSet setWithArray:self.basic_block.thread.stack.internalStack];
    for(id obj in set) {
        if([obj isKindOfClass:[FrameAddress class]]) {
            FrameAddress *addr = obj;
            addr.slot =  @(addr.slot.integerValue + ( sub));
        }
    }
    
    
    
}
@end
@implementation I8ImmInstr
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    UInt32 opcode = bytes[0];
    switch(opcode)
    {
        
        case 52:
            self.name = @"ArrayGetP1";
            break;
        case 53:
            self.name = @"ArrayGet1";
            break;
        case 54:
            self.name = @"ArraySet1";
            break;
        case 55:
            self.name = @"pframe1";
            break;
        case 56:
            self.name = @"getf";
            break;
        case 57:
            self.name = @"setf";
            break;
        case 64:
            self.name = @"getimmp1";
            break;
        case 65:
            self.name = @"getimm1";
            break;
        case 66:
            self.name = @"setimm1";
            break;
        case 79:
            self.name = @"pstatic2";
            break;
        case 101:
            self.name = @"scpy";
            break;
        case 102:
            self.name = @"itos";
            break;
        case 103:
            self.name = @"sadd";
            break;
        case 104:
            self.name = @"saddi";
            break;
    };
    self.opcode = opcode;
    self.size = 2;
    self.imm = bytes[1];
    self.name = [self.name stringByAppendingFormat:@" %u", self.imm];
    return self;
}
-(void)execute:(RSVM *)vm
{
    //56 gef 57 setf
    if(self.opcode == 53)
    {
        id address = [self.basic_block.thread.stack pop];
        NSNumber *arrIndex = [self.basic_block.thread.stack pop];
        NSUInteger index = (self.imm * 8) * arrIndex.intValue;
        if([address isKindOfClass:[GlobalAddress class]])
        {
            
            GlobalAddress *addr = [address copy];
                        [addr.string appendFormat:@"[%d <%d>]", arrIndex.intValue, self.imm];
            Byte *globals = (Byte*)((long long)&(vm.globals[addr.slot.unsignedLongValue+index]));
            [self.basic_block.thread.stack push:@(*globals)];
            
        } else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *addr = [address copy];
            NSUInteger index = [self.basic_block.thread getRealIndexFromFrameOffset:addr.slot.unsignedLongLongValue];
            index -= index/8;
            [self.basic_block.thread.stack push:[self.basic_block.thread.stack.internalStack objectAtIndex:index]];
            
        } else if([address isKindOfClass:[StaticAddress class]]) {
            StaticAddress *addr = address;
            NSUInteger index = self.imm * arrIndex.intValue;
            [self.basic_block.thread.stack push:[self.basic_block.thread.statics objectAtIndex:addr.slot.intValue+index]];
        }else {
            [super execute:vm];
        }
    }
    else if(self.opcode == 52)
    {
        id address = [self.basic_block.thread.stack pop];
        NSNumber *arrIndex = [self.basic_block.thread.stack pop];
        NSUInteger index = (self.imm * 8)*arrIndex.intValue;
        
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            addr.address = (void*)((long long)&(vm.globals[addr.slot.unsignedLongValue+index]));
            addr.slot = @(addr.slot.unsignedIntValue + index);
                        [addr.string appendFormat:@"[%d <%d>]", arrIndex.intValue, self.imm];
            [self.basic_block.thread.stack push:addr];
            
        } else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *addr = [address copy];
            addr.slot = @(addr.slot.intValue + (arrIndex.intValue * self.imm));
            [self.basic_block.thread.stack push:addr];
            
        } else if([address isKindOfClass:[StaticAddress class]]) {
            StaticAddress *addr = [address copy];
            addr.slot = @(addr.slot.intValue + (arrIndex.intValue * self.imm));
            [self.basic_block.thread.stack push:addr];
            
        }
        else
            [super execute:vm];
        
    } else if(self.opcode == 54) {
        
        id address = [self.basic_block.thread.stack pop];
        NSNumber *arrIndex = [self.basic_block.thread.stack pop];
        NSNumber *value = [self.basic_block.thread.stack pop];
        
        NSUInteger index = (self.imm * 8) * arrIndex.intValue;
        if([address isKindOfClass:[GlobalAddress class]])
        {
            if(strcmp([value objCType], @encode(float))==0) {
            GlobalAddress *addr = [address copy];
            [addr.string appendFormat:@"[%d <%d>]", arrIndex.intValue, self.imm];
            float *globalAddr = (float*)&(self.basic_block.thread.xscFile->globals->data[addr.slot.unsignedIntegerValue+(index)]);//(uint64_t*)(Byte*)((long long)addr.address+(index*self.imm));
            *globalAddr = value.floatValue;
            } else {
                GlobalAddress *addr = [address copy];
                
                uint64_t *globalAddr = (uint64_t*)(self.basic_block.thread.xscFile->globals->data +(addr.slot.unsignedIntegerValue+(index)));//(uint64_t*)(Byte*)((long long)addr.address+(index*self.imm));
                *globalAddr = value.unsignedIntegerValue;
            }
        } else if([address isKindOfClass:[StaticAddress class]]) {
            StaticAddress *sAddr = address;
            NSUInteger slot = self.imm * arrIndex.intValue;
            [self.basic_block.thread.statics replaceObjectAtIndex:slot withObject:value];
            
        }else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *sAddr = address;
            NSUInteger slot = self.imm * arrIndex.intValue;
            
            [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:[self.basic_block.thread getRealIndexFromFrameOffset:slot] withObject:value];
            
        }else {
            [super execute:vm];
        }
        
    } else if(self.opcode == 55)
    {
        UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:self.imm];//(self.basic_block.thread.stack.internalStack.count-self.basic_block.thread.framePointer) + self.basic_block.thread.stack.internalStack.count-1-self.imm-2;
        FrameAddress *fa = [[FrameAddress alloc] init];
        fa.slot = @(self.imm);
        fa.address = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
        fa.sourceInstr = self;
        [self.basic_block.thread.stack push:fa];
        
    }
    else if(self.opcode == 56)
    {
        UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:self.imm];
        id obj = self.basic_block.thread.stack.internalStack[index];
        [self.basic_block.thread.stack push:obj];
    } else if(self.opcode == 57)
    {
        id obj = [self.basic_block.thread.stack pop];
        UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:self.imm];

        [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:index withObject:obj];
        
    }
    else if(self.opcode == 64)
    {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            
            addr.address = &(self.basic_block.thread.xscFile->globals->data[self.imm*8]);
            addr.slot = @(addr.slot.intValue+(self.imm*8));
                        [addr.string appendFormat:@".imm_%d", self.imm];
            [self.basic_block.thread.stack push:addr];
        } else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *frameAddr = [address copy];
            
            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:(self.imm+frameAddr.slot.integerValue)];//(self.basic_block.thread.stack.internalStack.count-self.basic_block.thread.framePointer) + self.basic_block.thread.stack.internalStack.count-1-self.imm-2;
            FrameAddress *fa = [[FrameAddress alloc] init];
            fa.slot = @((self.imm+frameAddr.slot.integerValue));
            fa.address = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            fa.sourceInstr = self;
            [self.basic_block.thread.stack push:fa];
        } else if([address isKindOfClass:[StaticAddress class]]) {
            StaticAddress *addr = [address copy];
            addr.slot = @(addr.slot.unsignedIntegerValue+self.imm);
            [self.basic_block.thread.stack push:addr];
            
        }
        else
            [super execute:vm];
    }
    else if(self.opcode == 65)
    {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            if(addr.address == 0)
                [self.basic_block.thread.stack push:@(0)];
            
            addr.address = (void*)((long long)&(vm.globals[addr.slot.unsignedLongValue+(self.imm*8)]));
            addr.slot = @(addr.slot.intValue+(self.imm*8));
                        [addr.string appendFormat:@".imm_%d", self.imm];
            [self.basic_block.thread.stack push:@(*((uint64_t*)addr.address))];
        }
        else if([address isKindOfClass:[FrameAddress class]])
        {
            FrameAddress *addr = [address copy];
            NSUInteger index = [self.basic_block.thread getRealIndexFromFrameOffset:addr.slot.unsignedIntegerValue + self.imm];
            id obj = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            if(true)//[obj isKindOfClass:[NSNumber class]])
            {
                [self.basic_block.thread.stack push:obj];
            }
        } else if([address isKindOfClass:[StaticAddress class]]) {
            
            StaticAddress *addr = [address copy];
            NSUInteger index = addr.slot.unsignedIntegerValue + self.imm;
            id obj = [self.basic_block.thread.statics objectAtIndex:index];
            if(true)//[obj isKindOfClass:[NSNumber class]])
            {
                [self.basic_block.thread.stack push:obj];
            }
        }else
            [super execute:vm];
    } else if(self.opcode == 104) {
        id address = [self.basic_block.thread.stack pop];
        NSNumber *toAdd = [self.basic_block.thread.stack pop];
        
        //StringPointer *str = [self.basic_block.thread.stack pop];
        
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *globalAddress = [address copy];
            
            char **dst = (char**)(&self.basic_block.thread.xscFile->globals->data[globalAddress.slot.unsignedIntegerValue]);//(char**)globalAddress.address;
            char *source = *dst;
            
            sprintf(source, "%s%d", source, toAdd.unsignedIntValue);
            
            //*dst = (char*)(((long long)source) & 0x00000000FFFFFFFF);
        }
        else if([address isKindOfClass:[StaticAddress class]])
        {
            StaticAddress *staticAddress = [address copy];
            
            
            char *source = (char*)(void*)[self.basic_block.thread.statics[[staticAddress.slot intValue]] unsignedIntegerValue];
            
            sprintf(source, "%s%d", source, toAdd.unsignedIntValue);
            
        } else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *frameAddress = [address copy];
            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:frameAddress.slot.unsignedIntegerValue];
            StringPointer *newStringPointer = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            char *source = newStringPointer.string;
            
            sprintf(source, "%s%d", source, toAdd.unsignedIntValue);
            
        } else {
            [super execute:vm];
        }
    } else if(self.opcode == 103) {
        StringPointer *lhs = [self.basic_block.thread.stack pop];
        char *lhsString = NULL;//lhs.string;
        if([lhs isKindOfClass:[FrameAddress class]]) {
            FrameAddress *fa = (FrameAddress*)lhs;
            lhs = ((FrameAddress*)lhs).address;
            if([lhs isKindOfClass:[NSNumber class]]) {
                //uint64_t *temp = (uint64_t*)[((NSNumber*)lhs) unsignedLongValue];
                //lhsString = (char*)temp;
                lhsString = new char[self.imm+1];
                memset(lhsString, 0, self.imm);
                UInt64 *casted = (UInt64*)lhsString;
                uint32_t index = [self.basic_block.thread getRealIndexFromFrameOffset:fa.slot.unsignedIntegerValue];
                int j=0;
                bool shouldContinue = true;
                while(shouldContinue) {
                    NSNumber *obj = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
                    if(obj == nil || [obj isKindOfClass:[NSNumber class]] == NO)
                        break;
                    uint64_t val = [obj unsignedLongValue];
                    casted[j] = val;
                    for(int i=0; i<8; i++) {
                        if((val & (0xFF << 8*i)) == 0) {
                            shouldContinue = false;
                            break;
                        }
                    }
                    index--;
                    j++;
                }
            } else
                lhsString = lhs.string;
        } else if([lhs isKindOfClass:[StringPointer class]]) {
            lhsString = lhs.string;
        } else if([lhs isKindOfClass:[NSNumber class]]) {
            uint64_t *temp = (uint64_t*)[((NSNumber*)lhs) unsignedLongValue];
            lhsString = (char*)temp;
            
        }else {
            [super execute:vm];
        }
        //id *toAdd = [self.basic_block.thread.stack pop];
        
        
        StringPointer *rhs = [self.basic_block.thread.stack pop];
        char *rhsstring = NULL;//rhs.string;
        if([rhs isKindOfClass:[FrameAddress class]]) {
            FrameAddress *fa = (FrameAddress*)rhs;
            rhs = ((FrameAddress*)lhs).address;
            if([rhs isKindOfClass:[NSNumber class]]) {
                //uint64_t *temp = (uint64_t*)[((NSNumber*)lhs) unsignedLongValue];
                //lhsString = (char*)temp;
                rhsstring = new char[self.imm];
                memset(rhsstring, 0, self.imm);
                UInt64 *casted = (UInt64*)rhsstring;
                uint32_t index = [self.basic_block.thread getRealIndexFromFrameOffset:fa.slot.unsignedIntegerValue];
                int j=0;
                bool shouldContinue = true;
                while(shouldContinue) {
                    NSNumber *obj = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
                    if(obj == nil || [obj isKindOfClass:[NSNumber class]] == NO)
                    break;
                    uint64_t val = [obj unsignedLongValue];
                    casted[j] = val;
                    for(int i=0; i<8; i++) {
                        if((val & (0xFF << 8*i)) == 0) {
                        shouldContinue = false;
                            break;
                        }
                    }
                    index--;
                    j++;
                }
            } else
            rhsstring = rhs.string;
        }else if([rhs isKindOfClass:[StringPointer class]]) {
            rhsstring = rhs.string;
        }else {
            [super execute:vm];
        }
        if(lhsString != 0 && rhsstring != 0) // (unsigned long)lhsString != 0x100000000 &&

            sprintf(lhsString, "%s%s", lhsString, rhsstring);
        else {
            
        }
        
        
//        if([address isKindOfClass:[GlobalAddress class]])
//        {
//            GlobalAddress *globalAddress = [address copy];
//            
//            char **dst = (char**)(&self.basic_block.thread.xscFile->globals->data[globalAddress.slot.unsignedIntegerValue]);//(char**)globalAddress.address;
//            char *source = *dst;
//            
//            sprintf(source, "%s%d", source, toAdd.unsignedIntValue);
//            
//            //*dst = (char*)(((long long)source) & 0x00000000FFFFFFFF);
//        }
//        else if([address isKindOfClass:[StaticAddress class]])
//        {
//            StaticAddress *staticAddress = [address copy];
//            
//            
//            char *source = (char*)(void*)[self.basic_block.thread.statics[[staticAddress.slot intValue]] unsignedIntegerValue];
//            
//            sprintf(source, "%s%d", source, toAdd.unsignedIntValue);
//            
//        } else if([address isKindOfClass:[FrameAddress class]]) {
//            FrameAddress *frameAddress = [address copy];
//            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:frameAddress.slot.unsignedIntegerValue];
//            StringPointer *newStringPointer = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
//            char *source = newStringPointer.string;
//            
//            sprintf(source, "%s%d", source, toAdd.unsignedIntValue);
//            
//        } else {
//            [super execute:vm];
//        }
    }
    else if(self.opcode == 66)
    {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            NSNumber* val = [self.basic_block.thread.stack pop];
            GlobalAddress *addr = [address copy];
            [addr.string appendFormat:@".imm_%d", self.imm];
            addr.slot = @(addr.slot.intValue+(self.imm*8));
            addr.address = (void*)(&self.basic_block.thread.xscFile->globals->data[addr.slot.unsignedIntegerValue]);
            *((uint64_t*)addr.address) = val.unsignedIntegerValue;
        } else if([address isKindOfClass:[FrameAddress class]])
        {
            FrameAddress *addr = [address copy];
            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:(self.imm+addr.slot.integerValue)];
            id val = [self.basic_block.thread.stack pop];
            self.basic_block.thread.stack.internalStack[index] = val;
            
        } else if([address isKindOfClass:[StaticAddress class]]) {
            
            FrameAddress *addr = [address copy];
            UInt32 index = (self.imm+addr.slot.integerValue);
            id val = [self.basic_block.thread.stack pop];
            [self.basic_block.thread.statics replaceObjectAtIndex:index withObject:val];
        }
        else
            [super execute:vm];
    }
    else
    {
        [super execute:vm];
    }
}
@end
@implementation StaticSet

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 60)
    {
        self = [super initWithName:@"setstatic" size:2 andOpcode:60];
        self.imm = bytes[1];
    }
    return self;
}
-(NSString*)description
{
    
    return [NSString stringWithFormat:@"setstatic %d", self.imm ];
}
-(void)execute:(RSVM *)vm
{
    NSNumber *value = [self.basic_block.thread.stack pop];
    //if((strcmp([value objCType], @encode(float)) == 0))
        self.basic_block.thread.statics[self.imm] = value;
}
@end

@implementation StaticGet

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 59)
    {
        self = [super initWithName:@"getstatic" size:2 andOpcode:59];
        self.imm = bytes[1];
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"getlocal %d", self.imm ];
}

-(void)execute:(RSVM *)vm {
    id obj = self.basic_block.thread.statics[self.imm];
    [self.basic_block.thread.stack push:obj];
}
@end

@implementation FoldedInstr
-(void)execute:(RSVM *)vm {
    for(Instr *inst in self.foldedInstructions) {
        [inst execute:vm];
    }
}
@end

@implementation FoldedSetStatic

-(id)initWithPush:(PushInstr *)pushInstr andSetLocal:(StaticSet *)setLocal
{
    self = [self init];
    if(self) {
        self.foldedInstructions = @[pushInstr, setLocal];
        self.offset = pushInstr.offset;
        self.size = pushInstr.size + setLocal.size;
        self.description = [NSString stringWithFormat:@"statics[%d] = %@", ((StaticSet*)setLocal).imm, pushInstr.pushValue];
    }
    return self;
}

-(id)initWithNative:(CallNative *)native andSetLocal:(StaticSet *)setLocal
{
    self = [self init];
    if(self) {
        self.foldedInstructions = @[native, setLocal];
        self.offset = native.offset;
        self.size = native.size + setLocal.size;
        self.description = [NSString stringWithFormat:@"statics[%d] = %@", ((StaticSet*)setLocal).imm, native];
    }
    return self;
}

-(id)initWithFoldedStringPush:(FoldedStringPush*)push andSetLocal:(Instr*)setLocal
{
    self = [self init];
    if(self) {
        self.foldedInstructions = @[push, setLocal];
        self.offset = push.offset;
        self.size = push.size + setLocal.size;
        self.description = [NSString stringWithFormat:@"statics[%d] = (char*)\"%@\"", ((StaticSet*)setLocal).imm, push.string];
    }
    return self;
}

@end

@implementation FoldedGetLocal
-(id)initWithPush:(Instr *)pushInstr andGetLocal:(Instr *)getLocal
{
    self = [self init];
    if(self) {
        self.foldedInstructions = @[pushInstr, getLocal];
        self.offset = pushInstr.offset;
        self.size = pushInstr.size + getLocal.size;
    }
    return self;
}

@end

@implementation PushI8

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 37)
    {
        self = [super initWithName:@"PushI8" size:2 andOpcode:37];
        self.pushValue = @(bytes[1]);
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"PushI8 %@", self.pushValue];
}
@end

@implementation PushI88

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 38)
    {
        self = [super initWithName:@"PushI88" size:3 andOpcode:37];
        self.imm = bytes[1];
        self.imm2 = bytes[2];
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"PushI88 %d %d", self.imm, self.imm2];
}
-(void)execute:(RSVM *)vm
{
    [self.basic_block.thread.stack push:@(self.imm)];
        [self.basic_block.thread.stack push:@(self.imm2)];
}
@end
@implementation PushI888

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 39)
    {
        self = [super initWithName:@"PushI888" size:4 andOpcode:37];
        self.imm = bytes[1];
        self.imm2 = bytes[2];
        self.imm3 = bytes[3];
        
    }
    return self;
}

-(NSString*)description
{
    return [NSString stringWithFormat:@"PushI888 %d %d %d", self.imm, self.imm2, self.imm3];
}

-(void)execute:(RSVM *)vm
{
    [self.basic_block.thread.stack push:@(self.imm)];
    [self.basic_block.thread.stack push:@(self.imm2)];
        [self.basic_block.thread.stack push:@(self.imm3)];
}

@end
@implementation FoldedStringPush

-(id)initWithPush:(PushInstr*)val andStringPush:(PushString*)pushString withStringTable:(Byte*)strings
{
    self = [super init];
    self.string = [NSString stringWithUTF8String:(char*)(strings+val.pushValue.intValue)];
    self.name = [NSString stringWithFormat:@"PushString \"%@\"", self.string];
    self.size = val.size + pushString.size;
    self.offset = val.offset;
    self.foldedInstructions = @[val, pushString];
    self.stringIndex = [val.pushValue intValue];
    return self;
}

@end

@implementation FoldedCall


-(id)initWithCall:(Call*)call{
    
    EntryPointInstr *entry = nil;
//    ReturnInstr *ret = nil;
//    for(ScriptFunction *func in call.basic_block.thread.functions) {
//        BasicBlock *firstBlock = func.basic_blocks.firstObject;
//        if(call.callOffset == ((Instr*)firstBlock.instructions.firstObject).offset) {
//            entry = firstBlock.instructions.firstObject;
//            ret = ((BasicBlock*)func.basic_blocks.lastObject).instructions.lastObject;
//            break;
//        }
//    }
    
    int i = [call.basic_block.instructions indexOfObject:call];
    int param_count = entry.paramCount;
    BOOL should_break = false;
    NSMutableArray *param_array = [[NSMutableArray alloc] init];
        if(i>param_count)
        {

          
            for(int j=1; j<param_count+1; j++)
            {
                if([call.basic_block.instructions[i-j] isKindOfClass:[PushInstr class]]) {
                    [param_array addObject:call.basic_block.instructions[i-j]];
                }
                else {
                    should_break = true;
                }
            }
        }
    
    NSMutableArray *folded = [[NSMutableArray alloc] init];
    if(!should_break) {
        [folded addObjectsFromArray:param_array];
    }
    
    [folded addObject:call];
    self.foldedInstructions = folded;
    
    NSMutableString *str = [[NSMutableString alloc] init];
    
    if(call.returnCount == 0) {
        //[str appendString:@"(void)"];
    } else if(call.returnCount == 1) {
        [str appendString:@"(auto)"];
    } else {
        [str appendFormat:@"(auto[%d])", call.returnCount];
    }
    
    [str appendFormat:@"func_%d(", call.callOffset];
    if(param_count == param_array.count && param_count > 0) {
        for(int i=0; i<param_count; i++) {
            PushInstr *inst = param_array[i];
            [str appendFormat:@"%@", inst.pushValue];
            if(i < (param_count -1)) {
                [str appendString:@", "];
            }
        }
    } else if(param_count > 0){
        for(int i=0; i<param_count; i++) {
            [str appendFormat:@"stack[%d]", param_count-i];
            if(i < (param_count -1)) {
                [str appendString:@", "];
            }
        }
        
    } else {
        [str appendString:@"void"];
    }
    
    [str appendString:@");"];
    self.name = str;

    
    return self;
}

@end
@implementation PushString

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 99)
    {
        self = [super initWithName:@"SPush" size:1 andOpcode:99];
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"SPush"];
}
-(void)execute:(RSVM *)vm
{
    NSNumber *index = [[self.basic_block.thread stack] pop];
    if(index != 0)
        NSAssert([index isKindOfClass:[NSNumber class]], @"String index is not a number");
    StringPointer *string = [[StringPointer alloc] initWithInstr:self andStringIndex:[index intValue]];
    [[self.basic_block.thread stack] push:string];
}
@end

@implementation PushF32

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 41)
    {
        self = [super initWithName:@"PushF32" size:5 andOpcode:41];
        float *temp = (float*)(bytes+1);
       // CFSwappedFloat32 swapped;
       // swapped.v = *temp;
        
        
        self.imm = *temp;//CFConvertFloat32SwappedToHost(swapped);//0x9A9919BD;
        self.pushValue = @(self.imm);
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"PushF %f", self.imm];
}
@end

@implementation PushI32

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 40)
    {
        self = [super initWithName:@"PushI32" size:5 andOpcode:41];
        UInt32 *temp = (UInt32*)(bytes+1);
        self.imm = CFSwapInt32(*temp);
        self.pushValue = @(self.imm);
       
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"PushI32 %d", self.imm];
}
@end

@implementation StackGetP

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 58)
    {
        self = [super initWithName:@"pStatic" size:2 andOpcode:opcode];
        self.imm = bytes[1];
    }
    return self;
}
-(NSString*)description
{
    return [NSString stringWithFormat:@"pStatic %d", self.imm];
}
-(void)execute:(RSVM*)vm
{
    StaticAddress *addr = [[StaticAddress alloc] init];
    [addr setSlot:@(self.imm)];
    [addr setSourceInstr:self];
    [[self.basic_block.thread stack] push:addr];
    //[[self.basic_block.thread stack] push:@(self.imm)];
}
@end

@implementation SetPointer

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 48)
    {
        self = [super initWithName:@"SetPointer" size:1 andOpcode:opcode];
    }
    return self;
}
-(NSString*)description
{
    return self.name;
}
-(void)execute:(RSVM*)vm {
    id addr = [self.basic_block.thread.stack pop];
    NSNumber *val = [self.basic_block.thread.stack pop];
    if([addr isKindOfClass:[GlobalAddress class]]) {
        uint64_t *address = (uint64_t*)&(vm.globals[((GlobalAddress*)addr).slot.unsignedIntegerValue]);
        *address = (uint64_t)val.unsignedIntegerValue;
        
    } else if([addr isKindOfClass:[FrameAddress class]]) {
        FrameAddress *frameAddr = addr;
        
        UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:frameAddr.slot.unsignedIntegerValue];//(self.basic_block.thread.stack.internalStack.count-
        [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:index withObject:val];
        
    }else if([addr isKindOfClass:[StaticAddress class]]) {
        
        StaticAddress *sAddr = addr;
        UInt32 index = (sAddr.slot.integerValue);

        [self.basic_block.thread.statics replaceObjectAtIndex:index withObject:val];
    }else {
        [super execute:vm];
    }
}
@end
@implementation I16ImmInstr
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    switch(opcode)
    {
            
        case 70:
            self.name = @"GetImmP2";
            break;
        case 71:
            self.name = @"GetImm2";
            break;
        case 72:
            self.name = @"SetImm2";
            break;
        case 73:
            self.name = @"ArrayGetP2";
            break;
        case 74:
            self.name = @"ArrayGet2";
            break;
        case 75:
            self.name = @"ArraySet2";
            break;
        case 76:
            self.name = @"pframe2";
            break;
        case 77:
            self.name = @"frameget2";
            break;
        case 78:
            self.name = @"frameset2";
            break;
        case 79:
            self.name = @"pstatic2";
            break;
        case 80:
            self.name = @"staticget2";
            break;
        case 81:
            self.name = @"staticset2";
            break;
        case 82:
            self.name = @"pglobal2";
            break;
        case 83:
            self.name = @"globalget2";
            break;
        case 84:
            self.name = @"globalset2";
            break;

    };
    self.size = 3;
    self.opcode = (UInt32)opcode;
    UInt16 *temp = (UInt16*)&bytes[1];
    self.imm = CFSwapInt16(*temp);
    
    self.name = [self.name stringByAppendingFormat:@"\t %d", self.imm ];
    return self;
}
-(void)execute:(RSVM *)vm
{
    if(self.opcode == 83)
        [self.basic_block.thread.stack push:[vm getGlobal:self.imm*8]];
    else if(self.opcode == 81) {
        NSNumber *value = [self.basic_block.thread.stack pop];
        //if((strcmp([value objCType], @encode(float)) == 0))
        self.basic_block.thread.statics[self.imm] = value;
    }
    else if(self.opcode == 84)
    {
        NSNumber *val = [self.basic_block.thread.stack pop];
        if(strcmp([val objCType], @encode(float))==0)
        {
            float primitiveVal = [val floatValue];
            float *dest = (float*)(&(vm.globals[self.imm*8]));
            *dest = primitiveVal;
        }
        else
        {
            UInt32 primitiveVal = [val unsignedIntegerValue];
            uint64_t *dest = (uint64_t*)(&(vm.globals[self.imm*8]));
            *dest = primitiveVal;
        }
    } else if(self.opcode == 70) {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            [addr.string appendFormat:@".imm_%d", self.imm];
            
            addr.address = &(self.basic_block.thread.xscFile->globals->data[addr.slot.unsignedLongValue + self.imm*8]);//(void*)((long long)addr.address+(self.imm*8));
            addr.slot = @(addr.slot.intValue+(self.imm*8));
            [self.basic_block.thread.stack push:addr];
        } else if([address isKindOfClass:[FrameAddress class]]) {
            FrameAddress *frameAddr = [address copy];
            
            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:(self.imm+frameAddr.slot.integerValue)];//(self.basic_block.thread.stack.internalStack.count-self.basic_block.thread.framePointer) + self.basic_block.thread.stack.internalStack.count-1-self.imm-2;
            FrameAddress *fa = [[FrameAddress alloc] init];
            fa.slot = @((self.imm+frameAddr.slot.integerValue));
            fa.address = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            fa.sourceInstr = self;
            [self.basic_block.thread.stack push:fa];
        }
        else
            [super execute:vm];
    }else if(self.opcode == 71)
    {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            if(addr.address == 0)
                [self.basic_block.thread.stack push:@(0)];
            [addr.string appendFormat:@".imm_%d", self.imm];
            addr.address = (void*)&(vm.globals[addr.slot.unsignedLongValue+(self.imm*8)]);
            addr.slot = @(addr.slot.intValue+(self.imm*8));
            
            [self.basic_block.thread.stack push:@(*((uint64_t*)addr.address))];
        }
        else if([address isKindOfClass:[FrameAddress class]])
        {
            FrameAddress *addr = [address copy];
            NSUInteger index = [self.basic_block.thread getRealIndexFromFrameOffset:addr.slot.unsignedIntegerValue + self.imm];
            id obj = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
            if(true)//[obj isKindOfClass:[NSNumber class]])
            {
                [self.basic_block.thread.stack push:obj];
            }
        } else
            [super execute:vm];
    }else if(self.opcode == 72) {
        id address = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            NSNumber* val = [self.basic_block.thread.stack pop];
            GlobalAddress *addr = [address copy];
                        [addr.string appendFormat:@".imm_%d", self.imm];
            addr.slot = @(addr.slot.intValue+(self.imm*8));
            addr.address = (void*)(&self.basic_block.thread.xscFile->globals->data[addr.slot.unsignedIntegerValue]);
            *((uint64_t*)addr.address) = val.unsignedLongValue;
        } else if([address isKindOfClass:[FrameAddress class]])
        {
            FrameAddress *addr = [address copy];
            UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:(self.imm+addr.slot.integerValue)];
            id val = [self.basic_block.thread.stack pop];
            self.basic_block.thread.stack.internalStack[index] = val;
            
        }
        else
            [super execute:vm];
        
    } else if(self.opcode == 73) {
        id address = [self.basic_block.thread.stack pop];
        NSNumber *arrIndex = [self.basic_block.thread.stack pop];
        NSUInteger index = (self.imm * 8) * arrIndex.intValue;
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            addr.slot = @(addr.slot.unsignedIntegerValue + index);
            addr.address = &(vm.globals[addr.slot.unsignedIntegerValue]);
            
            [addr.string appendFormat:@"[%d <%d>]", arrIndex.intValue, self.imm];
            //  Byte *globals = (Byte*)((long long)addr.address+(index*self.imm));
            [self.basic_block.thread.stack push:addr];
            
        } else {
            [super execute:vm];
        }
    } else if(self.opcode == 74) {//get
        id address = [self.basic_block.thread.stack pop];
        NSNumber *arrIndex = [self.basic_block.thread.stack pop];
        NSUInteger index = (self.imm * 8) * arrIndex.intValue;
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            addr.slot = @(addr.slot.unsignedIntegerValue + index);
            addr.address = &(vm.globals[addr.slot.unsignedIntegerValue]);
            [addr.string appendFormat:@"[%d <%d>]", arrIndex.intValue, self.imm];
            //  Byte *globals = (Byte*)((long long)addr.address+(index*self.imm));
            [self.basic_block.thread.stack push:@(*(uint64_t*)addr.address)];
            
        } else {
            [super execute:vm];
        }
    } else if(self.opcode == 76) {
        UInt32 index = [self.basic_block.thread getRealIndexFromFrameOffset:self.imm];//(self.basic_block.thread.stack.internalStack.count-self.basic_block.thread.framePointer) + self.basic_block.thread.stack.internalStack.count-1-self.imm-2;
        FrameAddress *fa = [[FrameAddress alloc] init];
        fa.slot = @(self.imm);
        fa.address = [self.basic_block.thread.stack.internalStack objectAtIndex:index];
        fa.sourceInstr = self;
        [self.basic_block.thread.stack push:fa];
    }else if(self.opcode == 75) { //set
        id address = [self.basic_block.thread.stack pop];
        NSNumber *arrIndex = [self.basic_block.thread.stack pop];
        NSUInteger index = (self.imm * 8) * arrIndex.intValue;
        NSNumber *val = [self.basic_block.thread.stack pop];
        if([address isKindOfClass:[GlobalAddress class]])
        {
            GlobalAddress *addr = [address copy];
            addr.slot = @(addr.slot.unsignedIntegerValue + index);
            addr.address = &(vm.globals[addr.slot.unsignedIntegerValue]);
            [addr.string appendFormat:@"[%d <%d>]", arrIndex.intValue, self.imm];
            //  Byte *globals = (Byte*)((long long)addr.address+(index*self.imm));
            *(uint64_t*)addr.address = val.unsignedIntegerValue;
            
        } else {
            [super execute:vm];
        }
    }else {
        [super execute:vm];
    }
    
}
@end

@implementation Jump

-(void)setJumpTarget:(Instr *)jumpTarget {
    _jumpTarget = jumpTarget;
    
    if(_jumpTarget == nil) {
        NSLog(@"Nil JumpTarget");
    }
}
-(void)doJump
{
            VMThread *thread = self.basic_block.thread;
    if(self.jumpTarget != nil) {
        thread.currentInstruction = self.jumpTarget;
        thread.currentBlock = self.jumpTarget.basic_block;
        thread.currentIndex = [thread.currentBlock.instructions indexOfObject:self.jumpTarget];
        [thread.currentInstruction execute:thread.vm];
    } else {
        NSLog(@"WTF");
        [thread jumpToOffset:self.jumpOffset];
    }
    
}
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    self.opcode = opcode;
    self.size = 3;
    int16_t *temp = (int16_t*)&bytes[1];
    self.imm = CFSwapInt16(*temp);
    switch(opcode)
    {
        case 85:
            self.name = @"jmp";
            self.type = NO_ARITH;
            break;
        case 86:
            self.name = @"jz";
            self.type = NOT_ZERO;
            break;
        case 87:
            self.name = @"jne";
            self.type = CMPNE;
            break;
        case 88:
            self.name = @"jmpe";
            self.type = CMPEQ;
            break;
        case 89:
            self.name = @"jle";
            self.type = CMPLE;
            break;
        case 90:
            self.name = @"jl";
            self.type = CMPLT;
            break;
        case 91:
            self.name = @"jge";
            self.type = CMPGE;
            break;
        case 92:
            self.name = @"jg";
            self.type = CMPGT;
            break;
    }
    
    return self;
}
-(NSString*)description
{
    if(self.imm+self.offset+self.size == 108618)
        NSLog(@"found");
    return [NSString stringWithFormat:@"%@ %d", self.name, self.imm+self.offset+self.size];
}
-(UInt32)jumpOffset
{
    return self.imm+self.offset+self.size;
}
-(void)execute:(RSVM *)vm
{
    NSNumber *valOne = nil;//[self.basic_block.thread.stack pop];
    NSNumber *valTwo = nil;//[
    if(self.opcode != 85 && self.opcode != 86)
    {
        valOne = [self.basic_block.thread.stack pop];
        valTwo = [self.basic_block.thread.stack pop];
    }
    else if(self.opcode == 86)
        valOne = [self.basic_block.thread.stack pop];
    switch(self.opcode)
    {
        case 85:
            //[self.basic_block.thread jumpToOffset:[self jumpOffset]];
                [self doJump];
            break;
        case 86:
        {
            if([valOne intValue] == 0)
                    [self doJump];
            break;
        }
        case 87:
        {
            if([valOne intValue] != [valTwo intValue])
                           [self doJump];
            break;
        }
        case 88:
        {
            if([valOne intValue] == [valTwo intValue])
            [self doJump];
            break;
        }
        case 89:
        {
            if([valOne intValue] >= [valTwo intValue])
                            [self doJump];
            break;
        }
        case 90:
        {
            if([valOne intValue] > [valTwo intValue])
            [self doJump];
            break;
        }
        case 91:
        {
            if([valOne intValue] <= [valTwo intValue])
            [self doJump];
            break;
        }
        case 92:
        {
            if([valOne intValue] < [valTwo intValue])
            [self doJump];
            break;
        }
    }
}
@end



@implementation CallNative

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    static XSCFile *file = nil;
    if(file == nil)
        file =thread.xscFile;

    NSUInteger opcode = bytes[0];
    if(opcode == 44)
    {
        self = [super initWithName:@"Native" size:4 andOpcode:opcode];
        self.paramCount = bytes[1] >> 2;
        self.retFlag = bytes[1] & 0x3;
        UInt16 *temp = (UInt16*)&(bytes[2]);
        self.native = CFSwapInt16(*temp);
        
        self.native = ((bytes[2] << 8) | bytes[3]);
        //self.native = file->natives[self.native];
        UInt64 hash = thread.xscFile->natives[self.native];
        self.hash = hash;
        NSString *name = [[XSCDisassembler natives] objectForKey:@(hash)];
        NSString *retValue = @"void";
        if(self.retFlag == 1)
        {
            retValue = @"UInt32";
        }
        else if(self.retFlag > 1)
        {
            retValue = [NSString stringWithFormat:@"UInt32[%d]", self.retFlag];
        }
        self.name = [NSString stringWithFormat:@"%@ %@ (0x%llx)(%d params) : 0x%llx", retValue, name, hash, self.paramCount, self.native];
        
    }
    return self;
}
-(void)execute:(RSVM *)vm
{

    NSMutableArray *paramList = [[NSMutableArray alloc] init];
    for(int i=0; i<self.paramCount; i++)
    {
        id obj = [self.basic_block.thread.stack pop];
        if([obj isKindOfClass:[FrameAddress class]]) {
            FrameAddress *fa = obj;
            if([fa.address isKindOfClass:[StringPointer class]]) {
                [paramList addObject:fa.address];
                continue;
            }
        }
        [paramList addObject:obj];
        
    }


    NSString *str = [self.basic_block.thread.vm.realNatives objectForKey:@(self.hash)];
    if(str != nil)
    {
        SEL callback = NSSelectorFromString(str);
        id object = [self.basic_block.thread.vm.realNatives objectForKey:str];
        NSArray *retVal = [object performSelector:callback withObject:@{@"paramCount":@(self.paramCount), @"params":paramList}];
        if(retVal.count > 0)
        {
            for(id object in retVal)
            {
                [self.basic_block.thread.stack push:object];
            }
        }
    }else if(self.retFlag)
    {
        NSLog(@"Missing Native: %@ (%llx) [%d]", self.name, self.hash, self.offset);
        for(int i=0; i<self.retFlag; i++) {
            [self.basic_block.thread.stack push:@(1)];
        }
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"calledNative" object:nil userInfo:@{@"returnCount":@(self.retFlag)}];
    }

}//9ef0bc64
@end

@implementation Call

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];

    if(opcode == 93)
    {
        
        self = [super initWithName:@"Call" size:4 andOpcode:opcode];
        UInt32 *temp = (UInt32*)&bytes[0];
        self.callOffset = (*temp & 0xFFFFFF00) >> 8;
        self.callOffset = CFSwapInt32(self.callOffset);
        self.name = [self.name stringByAppendingFormat:@" %d", self.callOffset];
    }
    return self;
}

-(void)execute:(RSVM*)vm
{
    ReturnAddress *returnaddr = [[ReturnAddress alloc] init];
    [returnaddr setDestOffset:self.offset+self.size];
//    [returnaddr setSourceInstr:self];
    [self.basic_block.thread.stack push:returnaddr];
    
    [self.basic_block.thread jumpToOffset:self.callOffset];
}
@end


@implementation Dup

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    if(bytes[0] == 42)
    {
        self = [super initWithName:@"dup" size:1 andOpcode:42];
    }
    return self;
}
-(void)execute:(RSVM *)vm
{
    id lastObj = [self.basic_block.thread.stack pop];
    [self.basic_block.thread.stack push:lastObj];
    [self.basic_block.thread.stack push:[lastObj copy]];
}
@end

@implementation PCall

-(void)execute:(RSVM *)vm
{
    NSNumber *target = [self.basic_block.thread.stack pop];
    ReturnAddress *returnaddr = [[ReturnAddress alloc] init];
    [returnaddr setDestOffset:self.offset+self.size];
    [self.basic_block.thread.stack push:returnaddr];
    [self.basic_block.thread jumpToOffset:target.intValue];
}
@end

@implementation INot
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread{
    if(bytes[0] == 6)
    {
        self = [super initWithName:@"not" size:1 andOpcode:6];
    }
    return self;
}
-(void)execute:(RSVM *)vm
{
    NSNumber *num = [self.basic_block.thread.stack pop];
    unsigned int intVal = [num unsignedIntValue];
    [self.basic_block.thread.stack push:@(!intVal)];
}
@end

@implementation FNeg
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread{
    if(bytes[0] == 19)
    {
        self = [super initWithName:@"fneg" size:1 andOpcode:19];
    }
    return self;
}
@end

@implementation INeg
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread{
    if(bytes[0] == 7)
    {
        self = [super initWithName:@"neg" size:1 andOpcode:7];
    }
    return self;
}
@end

@implementation Switch

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    NSUInteger opcode = bytes[0];
    if(opcode == 98)
    {
        NSMutableArray *casesArr = [[NSMutableArray alloc] init];
        UInt32 cases = bytes[1];

        self.size = 2+cases*6;
        self.name  = @"switch";
        self.opcode = 98;
        for(int i=0; i<cases; i++)
        {

            UInt32 caseVal = CFSwapInt32(*(UInt32*)((Byte*)bytes+2+(i*6)));
            UInt16 jumpOffset = CFSwapInt16(*(UInt16*)((Byte*)bytes+6+(i*6)));
            [casesArr addObject:@{@"case":@(caseVal), @"offset":@(jumpOffset+self.offset+(i*6)+2+6)}];
        }
        self.cases = casesArr;
    }
    return self;
}
-(void)execute:(RSVM *)vm
{
    NSNumber *val = [self.basic_block.thread.stack pop];
    for(NSDictionary *dic in self.cases)
    {
        if([dic[@"case"] isEqualToNumber:val])
        {
            [self.basic_block.thread jumpToOffset:[dic[@"offset"] unsignedIntValue]];
            return;
        }
    }
}
@end


@implementation Imm24Instr

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"Imm24Instr" size:4 andOpcode:bytes[0]];
    UInt32 *temp = (UInt32*)&bytes[0];
    self.imm = (*temp & 0xFFFFFF00) >> 8;
    ;
    self.imm = CFSwapInt32(self.imm);
    switch(self.opcode)
    {
        case 95:
            self.name = @"globalget3";
            break;
        case 96:
            self.name = @"globalset3";
            break;
            
    }
    self.name = [self.name stringByAppendingFormat:@" %d", self.imm];
    return self;
}
-(void)execute:(RSVM *)vm
{
    if(self.opcode == 95)
    {
        [self.basic_block.thread.stack push:[vm getGlobal:self.imm]];
        
    }
    else if(self.opcode == 96)
    {
        NSNumber *val = [self.basic_block.thread.stack pop];
        if(strcmp([val objCType], @encode(float))==0)
        {
            float primitiveVal = [val floatValue];
            float *dest = (float*)(&(vm.globals[self.imm*8]));
            *dest = primitiveVal;
        }
        else
        {
            uint64_t primitiveVal = [val unsignedIntegerValue];
            uint64_t *dest = (uint64_t*)(&(vm.globals[self.imm*8]));
            *dest = primitiveVal;
        }
    }
}
@end

@implementation Push24Imm

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithBytes:bytes thread:thread];
    
    self.size = 4;
    self.opcode = bytes[0];
    UInt32 *temp = (UInt32*)&bytes[0];
    self.imm = (*temp & 0xFFFFFF00) >> 8;
    self.imm = CFSwapInt32(self.imm);
    self.pushValue = @(self.imm);
    self.name = [NSString stringWithFormat:@"Push %@", self.pushValue];
    return self;
}

@end
@implementation PGlobal3

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithBytes:bytes thread:thread];
    self.name = @"PGlobal3";
    self.name = [self.name stringByAppendingFormat:@" %d", self.imm];
    return self;
}

-(void)execute:(RSVM *)vm
{
    GlobalAddress *address = [[GlobalAddress alloc] init];
    [address setSlot:@(self.imm*8)];
//    [address setSourceInstr:self];
    address.string = [[NSMutableString alloc] initWithFormat:@"Globals_%d", self.imm];
    [address setAddress:&(self.basic_block.thread.xscFile->globals->data[self.imm*8])];
    [[self.basic_block.thread stack] push:address];
}
@end

@implementation PushI16
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithBytes:bytes thread:thread];
    self.size = 3;
    self.opcode = (UInt32)bytes[0];
    UInt16 *temp = (UInt16*)&bytes[1];
    self.imm = CFSwapInt16(*temp);
    self.pushValue = @(self.imm);
    self.name = [NSString stringWithFormat:@"Push %d", self.imm];
    
    return self;
}
@end

@implementation PopStack

-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"PopStack" size:1 andOpcode:43];
    return self;
}

-(void)execute:(RSVM *)vm {
    [self.basic_block.thread.stack pop];
}

@end

@implementation IAddImm8
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"immadd" size:2 andOpcode:61];
    self.imm = bytes[1];
    return self;
}
-(void)execute:(RSVM *)vm {
    NSNumber *val = [self.basic_block.thread.stack pop];
    val = @(val.unsignedIntegerValue+self.imm);
        [self.basic_block.thread.stack push:val];
}
@end

@implementation IMulImm8
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"immmul" size:2 andOpcode:62];
    self.imm = bytes[1];
    return self;
}

-(void)execute:(RSVM *)vm {
    NSNumber *val = [self.basic_block.thread.stack pop];
    val = @(val.unsignedIntegerValue*self.imm);
        [self.basic_block.thread.stack push:val];
}
@end

@implementation IAddImm16
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"immadd" size:3 andOpcode:68];
    UInt16 *temp = (UInt16*)&(bytes[1]);
    self.imm = CFSwapInt16(*temp);
    return self;
}

-(void)execute:(RSVM *)vm {
    NSNumber *val = [self.basic_block.thread.stack pop];
    val = @(val.unsignedIntegerValue+self.imm);
        [self.basic_block.thread.stack push:val];
}
@end

@implementation IMulImm16
-(id)initWithBytes:(Byte *)bytes thread:(VMThread*)thread
{
    self = [super initWithName:@"immmul16" size:3 andOpcode:69];
    UInt16 *temp = (UInt16*)&(bytes[1]);
    self.imm = CFSwapInt32(*temp);
    return self;
}
-(void)execute:(RSVM *)vm {
    NSNumber *val = [self.basic_block.thread.stack pop];
    val = @(val.unsignedIntegerValue*self.imm);
    [self.basic_block.thread.stack push:val];
}
@end
@implementation FoldedArrayFromStack

-(id)initWithFromStack:(ArrayFromStack*)fromStack getPointer:(StackGetP*)getPointer numValues:(PushInstr*)numValues andPushValues:(NSArray*)values
{
    self = [self init];


    NSMutableArray *foldedInstructions = [values mutableCopy];
    [foldedInstructions addObjectsFromArray:@[numValues, getPointer, fromStack]];

    self.offset = fromStack.offset;
    self.size = fromStack.size + getPointer.size + numValues.size;
    for(Instr *instr in values)
    {
        self.size += instr.size;
    }
    self.foldedInstructions = foldedInstructions;
    NSNumber *temp = [values[0] pushValue];
    NSMutableString *name = nil;
    
    if([getPointer isKindOfClass:[StackGetP class]])
        name = [[NSString stringWithFormat:@"memcpy(&statics[%d], %lu, [", [getPointer imm], (unsigned long)values.count] mutableCopy];
    else if([getPointer isKindOfClass:[PGlobal2 class]] || [getPointer isKindOfClass:[PGlobal3 class]])
        name = [[NSString stringWithFormat:@"memcpy(&globals[%d]  %lu, [", [getPointer imm], values.count] mutableCopy];
    else if([getPointer isKindOfClass:[FoldedGetAddressImmediate class]])
        name = [[NSString stringWithFormat:@"memcpy(%@, %lu, [", [getPointer.name substringWithRange:NSMakeRange(5, getPointer.name.length-6)], values.count] mutableCopy];
    else
        NSAssert((false), @"Unhandled pointer type  FoldedArrayFromStack");
    
    if((strcmp([temp objCType], @encode(int))) == 0) {

        for(int i=0; i<values.count; i++)
        {
            [name appendFormat:@"%@", [values[i] pushValue]];
            if(i != values.count -1)
                [name appendString:@", "];
        }
        [name appendString:@"]);"];
        self.name = name;
    } else if((strcmp([temp objCType], @encode(float))) == 0) {
        
        for(int i=0; i<values.count; i++)
        {
            [name appendFormat:@"%@", [values[i] pushValue]];
            if(i != values.count -1)
                [name appendString:@", "];
        }
        [name appendFormat:@"];"];
        self.name = name;
    }
    
    return self;
}

@end

@implementation FoldedTwoArgFloatArith

-(id)initWithArith:(FloatTwoArgArithInstr*)arith usingFirstPush:(PushInstr*)first andSecondPush:(PushInstr*)second
{
    self = [super init];
    if(self)
    {
        NSNumber *firstValue = nil;//first.pushValue;
        NSNumber *secondValue = nil;//second.pushValue;

            firstValue = first.pushValue;

            secondValue = second.pushValue;
        
        self.foldedInstructions = @[arith, first, second];
        self.size = arith.size;
        self.offset = second.offset;
        self.pushValue = [arith calculateWithFirst:firstValue andSecond:secondValue];
        self.name = [NSString stringWithFormat:@"PushF %@ - (%@ %@ %@)", self.pushValue, firstValue, [arith sign], secondValue];
    }
    return self;
}

@end

@implementation GlobalSet2
-(void)execute:(RSVM *)vm
{
    
    NSNumber *val = [self.basic_block.thread.stack pop];
    if(strcmp([val objCType], @encode(float))==0)
    {
        float primitiveVal = [val floatValue];
        float *dest = (float*)(&(vm.globals[self.imm*8]));
        *dest = primitiveVal;
    }
    else
    {
        uint64_t primitiveVal = [val unsignedIntegerValue];
        uint64_t *dest = (uint64_t*)(&(vm.globals[self.imm*8]));
        *dest = primitiveVal;
    }
}
@end

@implementation GlobalSet3
-(void)execute:(RSVM *)vm
{
    
    NSNumber *val = [self.basic_block.thread.stack pop];
    if(strcmp([val objCType], @encode(float))==0)
    {
        float primitiveVal = [val floatValue];
        float *dest = (float*)(&(self.basic_block.thread.xscFile->globals->data[self.imm*8]));
        *dest = primitiveVal;
    }
    else
    {
        UInt64 primitiveVal = [val unsignedIntegerValue];
        UInt64 *dest = (UInt64*)(&(self.basic_block.thread.xscFile->globals->data[self.imm*8]));
        *dest = primitiveVal;
    }
}
@end

@implementation FoldedGlobalSet

-(id)initWithGlobalSet:(GlobalSet2*)globalSet andPush:(PushInstr*)push
{
    self = [self init];
    self.foldedInstructions = @[push, globalSet];
    self.size = globalSet.size+push.size;
    self.offset = push.offset;
    self.pushValue = push.pushValue;
    self.name = [NSString stringWithFormat:@"globals[%d] = %@", globalSet.imm, push.pushValue];
    return self;
}

-(id)initWithGlobalSet3:(GlobalSet3*)globalSet andPush:(PushInstr*)push
{
    self = [self init];
    self.foldedInstructions = @[push, globalSet];
    self.size = globalSet.size+push.size;
    self.offset = push.offset;
    self.pushValue = push.pushValue;
    self.name = [NSString stringWithFormat:@"globals[%d] = %@", globalSet.imm, push.pushValue];
    return self;
}

-(id)initWithGlobalSet3:(GlobalSet3*)globalSet andGlobalGet2:(I16ImmInstr *)push
{
    self = [self init];
    self.foldedInstructions = @[push, globalSet];
    self.size = globalSet.size+push.size;
    self.offset = push.offset;
    //self.pushValue = push.pushValue;
    self.name = [NSString stringWithFormat:@"globals[%d] = globals[%d]", globalSet.imm, push.imm];
    return self;
}

-(id)initWithGlobalSet3:(GlobalSet3*)globalSet andGlobalGet3:(Imm24Instr *)push
{
    self = [self init];
    self.foldedInstructions = @[push, globalSet];
    self.size = globalSet.size+push.size;
    self.offset = push.offset;
    //self.pushValue = push.pushValue;
    self.name = [NSString stringWithFormat:@"globals[%d] = globals[%d]", globalSet.imm, push.imm];
    return self;
}


@end

@implementation PGlobal2
-(void)execute:(RSVM *)vm
{
    GlobalAddress *address = [[GlobalAddress alloc] init];
    [address setSlot:@(self.imm*8)];
//    [address setSourceInstr:self];
    address.string = [[NSMutableString alloc] initWithFormat:@"Globals_%d", self.imm];
    [address setAddress:&vm.globals[self.imm*8]];
    [[self.basic_block.thread stack] push:address];
}
@end

union stringRef {
    __unsafe_unretained StringPointer *test;
    unsigned long ptrVal;
    unsigned long *pointer;
};
@implementation SCpy
-(void)execute:(RSVM *)vm
{
    static NSMutableArray *spArr = [[NSMutableArray alloc] init];
    id address = [self.basic_block.thread.stack pop];
    StringPointer *str = [self.basic_block.thread.stack pop];
    if([str isKindOfClass:[FrameAddress class]]) {
        FrameAddress *fa = (id)str;
        str = (StringPointer*)fa.address;
    } else if([str isKindOfClass:[GlobalAddress class]]) {
        NSLog(@"SCpy test");
    }
   
    if(str != 0) {
        NSString *string = [NSString stringWithFormat:@"SCPY StrIndex is not an NSNumber : offset :(%d) - 0x%x", self.offset, self.offset];
        NSAssert([str isKindOfClass:[StringPointer class]], string);
    } else {
        return;
    }
    char *source = str.string;
    char *newStr = (char*)[vm.heap malloc:self.imm];
    
    NSString *test = [NSString stringWithUTF8String:str.string];
    if([test rangeOfString:@"FP15"].location != NSNotFound)
        NSLog(@"Found bad pointer");
    strcpy(newStr, source);
    if([address isKindOfClass:[GlobalAddress class]])
    {
        GlobalAddress *globalAddress = [address copy];
        char *dst = (char*)(&self.basic_block.thread.xscFile->globals->data[globalAddress.slot.unsignedIntegerValue]);
        strcpy(dst, str.string);
//        StringPointer *newStringPointer = [[StringPointer alloc] init];
//        newStringPointer.string = newStr;
//        newStringPointer.size = self.imm;
//        [spArr addObject:newStringPointer];
//        
//        stringRef *ref = new stringRef;
//        ref->test = newStringPointer;
//        
//        GlobalAddress *globalAddress = [address copy];
//        //StringPointer *test = (StringPointer*)(&self.basic_block.thread.xscFile->globals->data[globalAddress.slot.unsignedIntegerValue]);
//        char **dst = (char**)(&self.basic_block.thread.xscFile->globals->data[globalAddress.slot.unsignedIntegerValue]);//(char**)globalAddress.address;
//        *dst = newStr;//ref->ptrVal;//(unsigned long)(id)newStringPointer;//(char*)(((unsigned long long)newStr) & 0x00000000FFFFFFFF);
//        delete ref;
    }
    else if([address isKindOfClass:[StaticAddress class]])
    {
        StaticAddress *staticAddress = [address copy];
        self.basic_block.thread.statics[[staticAddress.slot intValue]] = @(newStr);
    } else if([address isKindOfClass:[FrameAddress class]]) {
        FrameAddress *frameAddress = [address copy];
        StringPointer *newStringPointer = [[StringPointer alloc] init];
        newStringPointer.size = self.imm;
        newStringPointer.string = newStr;
        int index = [self.basic_block.thread getRealIndexFromFrameOffset:[frameAddress slot].intValue];
        [self.basic_block.thread.stack.internalStack replaceObjectAtIndex:index withObject:newStringPointer];
        
        
        
    } else {
        [super execute:vm];
    }
}
@end
@implementation FoldedSCpy

-(id)initWithSCpy:(Instr*)scpy stackPointer:(StackGetP*)global andFoldedStringPush:(FoldedStringPush*)foldedStringPush
{
    self = [self init];
    self.offset = foldedStringPush.offset;
    self.size = foldedStringPush.size + global.size + scpy.size;
    self.foldedInstructions = @[foldedStringPush, global, scpy];
    
    self.name = [NSString stringWithFormat:@"statics[%d] = new string(\"%@\");", global.imm, foldedStringPush.string];
    return self;
}

-(id)initWithSCpy:(Instr*)scpy globalPointer3:(PGlobal3*)global andFoldedStringPush:(FoldedStringPush*)foldedStringPush
{
    self = [self init];
    self.offset = foldedStringPush.offset;
    self.size = foldedStringPush.size + global.size + scpy.size;
    self.foldedInstructions = @[foldedStringPush, global, scpy];
    
    self.name = [NSString stringWithFormat:@"globals[%d] = new string(\"%@\");", global.imm, foldedStringPush.string];
    return self;
}
-(id)initWithSCpy:(Instr*)scpy globalPointer2:(PGlobal2*)global andFoldedStringPush:(FoldedStringPush*)foldedStringPush
{
    self = [self init];
    self.offset = foldedStringPush.offset;
    self.size = foldedStringPush.size + global.size + scpy.size;
    self.foldedInstructions = @[foldedStringPush, global, scpy];
    
    self.name = [NSString stringWithFormat:@"globals[%d] = new string(\"%@\");", global.imm, foldedStringPush.string];
    return self;
}

@end

@implementation FoldedNative

-(id)initWithNative:(CallNative*)native params:(NSArray*)params
{
    self = [super init];
    self.offset = [[params lastObject] offset];
    self.basic_block = native.basic_block;
    
    NSMutableArray *instructions = [[NSMutableArray alloc] init];
    [params enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(Instr* obj, NSUInteger idx, BOOL *stop) {
        
        [instructions addObject:obj];
        self.size += [obj size];
    }];
    [instructions addObject:native];
    self.size +=native.size;
    self.foldedInstructions = instructions;
    self.paramCount = native.paramCount;
    self.native = native.native;
    self.retFlag = native.retFlag;
    UInt32 hash = self.basic_block.thread.xscFile->natives[self.native];
    NSString *name = [[XSCDisassembler natives] objectForKey:@(hash)];
    NSString *retValue = @"void";
    if(self.retFlag == 1)
    {
        retValue = @"UInt32";
    }
    else if(self.retFlag > 1)
    {
        retValue = [NSString stringWithFormat:@"UInt32[%d]", self.retFlag];
    }
    self.name = [NSString stringWithFormat:@"%@ %@ (", retValue, name];
    for(int i=0; i<params.count; i++)
    {
        PushInstr *inst = params[i];
        self.name = [self.name stringByAppendingFormat:@"%@%@", inst.pushValue, ((i!=(params.count-1)) ? @", " : @");")];
    }
    if(params.count == 0)
        [self.name stringByAppendingString:@")"];
    return self;
}

@end

@implementation FoldedGetAddressImmediate

-(id)initWithGetArrayP:(I8ImmInstr *)getparray {
    self = [super init];

    self.basic_block = getparray.basic_block;
    int i = [self.basic_block.instructions indexOfObject:getparray];
    NSMutableArray *folded = [[NSMutableArray alloc] init];
    NSMutableString *name = [@"" mutableCopy];
    [name appendString:@"push "];
    if(i>2) {
        Instr* address = self.basic_block.instructions[i-1];
        if([address isKindOfClass:[PGlobal2 class]] || [address isKindOfClass:[PGlobal3 class]]) {
            [name appendFormat:@"&(globals[%d]", ((GlobalSet3*)address).imm];
        }
        
        Instr* index = self.basic_block.instructions[i-2];
        if([index isKindOfClass:[PushInstr class]]) {
            [name appendFormat:@"[%d * %@]);", getparray.imm, ((PushInstr*)index).pushValue];
        } else if(index.opcode == 56) {
            [name appendFormat:@"[%d * framePointer[%d]]);", getparray.imm, ((I8ImmInstr*)index).imm];
        }
        
        self.foldedInstructions = @[index, address, getparray];
        self.offset = [self.foldedInstructions.firstObject offset];
        self.name = name;
        self.size = index.size + address.size + getparray.size;
        return self;
    } else {
        return nil;
    }
    
}

@end
