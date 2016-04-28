//
//  XSCDisassembler.m
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import "XSCDisassembler.h"
#import <stdlib.h>
#import "XSCFile.h"
#import "RSVM.h"
#import "Operation.h"

@interface XSCDisassembler()

@end
@implementation XSCDisassembler
+(instancetype)sharedInstance
{
    static XSCDisassembler *disassembler = nil;
    if(disassembler == nil)
        disassembler = [[XSCDisassembler alloc] init];
    return disassembler;
}
+(NSDictionary*)dictionaryFromNatives:(NSData*)data
{
    NSString *natives = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [natives enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSArray *tokens = [line componentsSeparatedByString:@":"];
        NSString *hash = tokens[0];
        NSNumber *num_hash = [formatter numberFromString:hash];
        if(num_hash == nil)
            return;
        [dic setObject:tokens[1] forKey:num_hash];
    }];
    return dic;
}
-(id)init
{
   // self.vm = [[RSVM alloc] init];
    self = [super init];

    
    //self.vm.globals = self.xscFile->globals->data;
    return self;
}

+(NSString*)getHashKey:(NSString*)orig usingTranslationTables:(NSArray*)tables {
    for(NSDictionary *table : tables) {
        NSString *temp = table[orig];
        if(temp != nil)
            orig = temp;
    }
    return orig;
}

+(NSNumber*)getHashFromJoaat:(NSNumber*)key usingTranslationTables:(NSArray*)tables {
    NSString *temp = [XSCDisassembler natives][key];
    NSMutableArray *objs =[[[XSCDisassembler natives] allKeysForObject:temp] mutableCopy];
    [objs removeObject:key];
    return objs.firstObject;
}



+(NSArray*)tables
{
    static NSArray *tables = nil;
    if(tables == nil) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"native_translation" ofType:@"json"];
        
        
        NSError *error;
        NSDictionary *translationDic = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:kNilOptions error:&error];
        
        tables = [translationDic[@"translation_tables"] mutableCopy];
        //[(NSMutableArray*)tables removeLastObject];
    }
    return tables;
}

+(NSDictionary*)natives
{
    static NSDictionary *nativesDic = nil;
    if(nativesDic != nil)
        return nativesDic;
    //    if(nativesDic == nil)
    //    {
    //        NSString *path = [[NSBundle mainBundle] pathForResource:@"natives" ofType:@"txt"];
    //        NSError *error;
    //        NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    //        nativesDic = [XSCDisassembler dictionaryFromNatives:data];
    //    }
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"natives" ofType:@"json"];
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile:path];
    
    
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    
    NSArray *tables = [XSCDisassembler tables];
    
    
    NSArray *keys = [dic allKeys];
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    
    NSMutableDictionary *finalNatives = [[NSMutableDictionary alloc] init];
    for(NSString *str : keys) {
        NSDictionary *o = dic[str];
        NSArray *moreKeys = [o allKeys];
        for(NSString *moreStr : moreKeys) {
            NSDictionary *native = o[moreStr];
            NSString *hash = native[@"jhash"];
            
            NSString * key = [XSCDisassembler getHashKey:[moreStr substringFromIndex:2] usingTranslationTables:tables];
            
            NSScanner* pScanner = [NSScanner scannerWithString: key];
            
            uint64_t iValue;
            //[pScanner scanHexInt: &iValue];
            [pScanner scanHexLongLong:&iValue];
            
            NSNumber *hashNumber  = @(iValue);//@(strtoll(hash.cString, NULL, 0));
            
            if([native[@"name"] length] > 0 && hashNumber != nil) {
                [finalNatives setObject:[((NSString*)native[@"name"]) lowercaseString] forKey:hashNumber];
                [finalNatives setObject:[((NSString*)native[@"name"]) lowercaseString] forKey:@(strtoll(hash.cString, NULL, 0))];
            }
        }
        
    }
    nativesDic = finalNatives;
    return nativesDic;
}

-(void)addLeader:(Instr *)leader fromInstruction:(Instr*)callee usingLeaders:(NSMutableSet **)leaders
{
    BOOL found = false;
    for(Leader *curLead in *leaders)
    {
        if([curLead offset] == [leader offset])
        {
            [[curLead ins] addObject:callee];
            found = true;
            break;
        }
    }
    if(!found)
    {
        Leader *lead = [[Leader alloc] init];
        lead.offset = leader.offset;
        if(callee != nil)
        [lead.ins addObject:callee];
        [*leaders addObject:lead];
    }
}

-(NSDictionary*)foldInstructions:(NSMutableDictionary*)input
{
    NSMutableArray *basic_blocks = input[@"blocks"];
    for(BasicBlock *block in basic_blocks)
    {
        for(int i=1; i<block.instructions.count; i++)
        {
            Instr *curInst = block.instructions[i];
            Instr *prevInst = i != 0 ? block.instructions[i-1] : nil;
            if([curInst isKindOfClass:[StaticSet class]])
            {
                
                StaticSet *set = curInst;
                if([set imm] == 71)
                    NSLog(@"found");
                if([prevInst isKindOfClass:[PushInstr class]])
                {
                    FoldedSetStatic *folded = [[FoldedSetStatic alloc] initWithPush:prevInst andSetLocal:curInst];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:@[curInst, prevInst]];
                    i = 0;
                    continue;
                }
                else if([prevInst isKindOfClass:[FoldedStringPush class]])
                {
                    FoldedSetStatic *folded = [[FoldedSetStatic alloc] initWithFoldedStringPush:prevInst andSetLocal:curInst];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:@[curInst, prevInst]];
                    i = 0;
                    continue;
                }
                else if([prevInst isKindOfClass:[FoldedNative class]] || [prevInst isKindOfClass:[CallNative class]])
                {
                    FoldedSetStatic *folded = [[FoldedSetStatic alloc] initWithNative:prevInst andSetLocal:curInst];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:@[curInst, prevInst]];
                    i = 0;
                    continue;
                }
            }
            else if([curInst isKindOfClass:[PushString class]])
            {
                if([prevInst isKindOfClass:[PushInstr class]])
                {
                    FoldedStringPush *folded = [[FoldedStringPush alloc] initWithPush:prevInst andStringPush:curInst withStringTable:self.xscFile->strings->data];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:@[curInst, prevInst]];
                    i = 0;
                    continue;
                }
            }
            else if([curInst opcode] == 52) {
                FoldedGetAddressImmediate *gai = [[FoldedGetAddressImmediate alloc] initWithGetArrayP:curInst];
                if(gai != nil) {
                    [curInst.basic_block.instructions insertObject:gai atIndex:i];
                    [curInst.basic_block.instructions removeObjectsInArray:gai.foldedInstructions];
                    i=0;
                    continue;
                }
            }
            else if([curInst isKindOfClass:[ArrayFromStack class]] && ([prevInst isKindOfClass:[StackGetP class]] || [prevInst isKindOfClass:[PGlobal2 class]]|| [prevInst isKindOfClass:[PGlobal3 class]] || [prevInst isKindOfClass:[FoldedGetAddressImmediate class]]))
            {
                int pushOffset = i-2;
                if(pushOffset > 0) {
                    PushInstr *push =block.instructions[pushOffset];
                    if([push isKindOfClass:[PushInstr class]])
                    {
                        int numvals = [push.pushValue intValue];
                        if((i - 2 - numvals) < 0)
                            continue;
                        else
                        {
                            BOOL failed = false;
                            NSMutableArray *valuesFromStack = [[NSMutableArray alloc] initWithCapacity:numvals];
                            for(int x=0; x<numvals; x++)
                            {
                                int index = i-3-x;
                                PushInstr *pushVal = block.instructions[index];
                                if([pushVal isKindOfClass:[PushInstr class]] == NO) {
                                    NSLog(@"Invalid push instruction %@ - ClassName : %@", pushVal, [pushVal class]);
                                    failed = true;
                                    break;
                                }
                                [valuesFromStack addObject:pushVal];
                                    
                            }
                            if(failed || valuesFromStack.count == 0)
                                break;
                            else
                            {
                                FoldedArrayFromStack *folded = [[FoldedArrayFromStack alloc] initWithFromStack:curInst getPointer:prevInst numValues:push andPushValues:valuesFromStack];
                                [block.instructions insertObject:folded atIndex:i];
                                [block.instructions removeObjectsInArray:folded.foldedInstructions];
                                i=0;
                                continue;
                            }
                        }
                        
                    }
                }
                
            }
            else if([curInst isKindOfClass:[FloatTwoArgArithInstr class]])
            {
                if(i < 2)
                    continue;
                
                PushInstr *thirdInstr = block.instructions[i-2];
                if(([prevInst isKindOfClass:[PushInstr class]] || [prevInst isKindOfClass:[FoldedTwoArgFloatArith class]]) && ([thirdInstr isKindOfClass:[PushInstr class]] || [thirdInstr isKindOfClass:[FoldedTwoArgFloatArith class]]))
                {
                    FoldedTwoArgFloatArith *folded = [[FoldedTwoArgFloatArith alloc] initWithArith:curInst usingFirstPush:prevInst andSecondPush:thirdInstr];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                }
            }
            else if([curInst isKindOfClass:[GlobalSet2 class]])
            {
                if([prevInst isKindOfClass:[PushInstr class]])
                {
                    FoldedGlobalSet *folded = [[FoldedGlobalSet alloc] initWithGlobalSet:curInst andPush:prevInst];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                }
            }
            else if([curInst isKindOfClass:[GlobalSet3 class]])
            {
                if([prevInst isKindOfClass:[PushInstr class]])
                {
                    FoldedGlobalSet *folded = [[FoldedGlobalSet alloc] initWithGlobalSet:curInst andPush:prevInst];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                }  else if(prevInst.opcode == 83 || prevInst.opcode == 95) {
                    FoldedGlobalSet *folded = [[FoldedGlobalSet alloc] initWithGlobalSet3:curInst andGlobalGet2:prevInst];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                }
            }
            else if([curInst isKindOfClass:[SCpy class]] && i >= 3)
            {
                 FoldedStringPush *push = block.instructions[i-2];
                if([prevInst isKindOfClass:[StackGetP class]] && [push isKindOfClass:[FoldedStringPush class]])
                {
                    FoldedSCpy *folded = [[FoldedSCpy alloc] initWithSCpy:curInst stackPointer:(StackGetP*)prevInst andFoldedStringPush:push];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                } else if([prevInst isKindOfClass:[PGlobal3 class]] && [push isKindOfClass:[FoldedStringPush class]]) {
                    FoldedSCpy *folded = [[FoldedSCpy alloc] initWithSCpy:curInst globalPointer3:(PGlobal3*)prevInst andFoldedStringPush:push];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                } else if([prevInst isKindOfClass:[PGlobal2 class]] && [push isKindOfClass:[FoldedStringPush class]]) {
                    FoldedSCpy *folded = [[FoldedSCpy alloc] initWithSCpy:curInst globalPointer2:(PGlobal2*)prevInst andFoldedStringPush:push];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                }
            }
            else if([curInst isKindOfClass:[CallNative class]])
            {
                CallNative *native = (CallNative*)curInst;
                int param_count = [native paramCount];
                if(i<param_count)
                    continue;
                
                NSMutableArray *param_array = [[NSMutableArray alloc] init];
                BOOL should_break = false;
                for(int j=1; j<param_count+1; j++)
                {
                    if([block.instructions[i-j] isKindOfClass:[PushInstr class]]) {
                        [param_array addObject:block.instructions[i-j]];
                    }
                    else {
                        should_break = true;
                    }
                }
                if(should_break)
                    continue;
                else if(param_array.count > 0)
                {
                    
                    FoldedNative *folded = [[FoldedNative alloc] initWithNative:curInst params:param_array];
                    [block.instructions insertObject:folded atIndex:i];
                    [block.instructions removeObjectsInArray:folded.foldedInstructions];
                    i=0;
                    continue;
                }
            } else if([curInst isKindOfClass:[Call class]]) {
                FoldedCall *folded = [[FoldedCall alloc] initWithCall:curInst];
                [block.instructions insertObject:folded atIndex:i];
                [block.instructions removeObjectsInArray:folded.foldedInstructions];
                i=0;
                continue;
            }
            
        }
    }
    
    
    NSMutableString *string = [@"" mutableCopy];
    for(BasicBlock *basic_block in basic_blocks)
    {
        [string appendFormat:@"loc_%d (%lu INS)\n", [([basic_block instructions][0]) offset], (unsigned long)basic_block.ins.count];
        for(Instr *instr in [basic_block instructions])
        {
            if([instr isKindOfClass:[FoldedInstr class]]) {
                            [string appendFormat:@"(%3i) %@\n", [[(FoldedInstr*)instr foldedInstructions][0] offset], [instr description]];
            } else {
            [string appendFormat:@"(%3i) %@\n", [instr offset], [instr description]];
            }
        }
        [string appendString:@"\n"];
    }
    [input setObject:string forKey:@"folded_string"];
    return input;
}
-(NSDictionary*)generateBasicBlocks:(NSDictionary*)input thread:(VMThread*)thread
{
    NSArray *instructions = input[@"code"];
    NSMutableSet *leaders = [[NSMutableSet alloc] init];
    NSMutableArray *basicBlocks = [[NSMutableArray alloc] init];
    if(instructions == nil)
        return nil;
    
    
    Instr *instruction = nil;
    for(int i=0; i<instructions.count; i++)
    {
//        if(i==0)
//        {
//            [leaders addObject:instructions[i]];
//            continue;
//        }
        instruction = instructions[i];
        switch([instruction opcode])
        {
            case 45:
                //[leaders addObject:instruction];
                [self addLeader:instruction fromInstruction:(i > 1 ? instructions[i-1] : nil) usingLeaders:&leaders];
                break;
            case 85:
            case 86:
            case 87:
            case 88:
            case 89:
            case 90:
            case 91:
            case 92:
            {
                Jump *jump = instruction;
                if(i+1 != instructions.count)
                [self addLeader:instructions[i+1] fromInstruction:instruction usingLeaders:&leaders];
                
                if(jump.imm > 0)
                {
                    
                    
                    //int count = 0;
                    for(int j=i+1; j<instructions.count; j++)
                    {
                        
                        if(jump.jumpOffset == [instructions[j] offset])
                        {
                             jump.jumpTarget = instructions[j];
                            [self addLeader:instructions[j] fromInstruction:instruction usingLeaders:&leaders];
                            break;
                        }
                       
                    }
                    if(jump.jumpTarget == nil)
                     NSLog(@"Jump Not found");
                }
                else
                {
                    int count = 0;
                    for(int j=i+1; j>=0; j--)
                    {
                        //count += [(Instr*)instructions[j+1] size];
                        if(jump.jumpOffset == [instructions[j] offset])//if(-count == jump.imm)
                        {
                            jump.jumpTarget = instructions[j];
                            [self addLeader:instructions[j] fromInstruction:instruction usingLeaders:&leaders];
                            break;
                        }
                    }
                    if(jump.jumpTarget == nil)
                     NSLog(@"Jump Not found");
                }
                break;
            }
        }
    }
    NSArray *sorted_leaders = [leaders sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"offset" ascending:YES]]];
    int current_leader = 0;
    BasicBlock *currentBlock = [[BasicBlock alloc] init];
    currentBlock.thread = thread;
    currentBlock.offsetStart = 0;
    Instr *instr = nil;
    Leader *currentLeader;
    for(int i=0; i<instructions.count; i++)
    {
        instr = instructions[i];
        if(sorted_leaders.count > 2 && ([instructions[i] offset] < [sorted_leaders[current_leader+1] offset] || current_leader == sorted_leaders.count-2))
        {
            
            [currentBlock.instructions addObject:instr];
            [instr setBasic_block:currentBlock];
            continue;
        }
        else
        {
            currentBlock.offsetEnd = [((Instr*)currentBlock.instructions.lastObject) size] + [currentBlock.instructions.lastObject offset];
            [basicBlocks addObject:currentBlock];
            current_leader++;
            currentLeader = sorted_leaders[current_leader];
            currentBlock = [[BasicBlock alloc] init];
            currentBlock.thread = thread;
            if(current_leader != sorted_leaders.count)
            currentBlock.ins = [sorted_leaders[current_leader] ins];
            [instr setBasic_block:currentBlock];
            [currentBlock.instructions addObject:instr];
            currentBlock.offsetStart = instr.offset;
        }
        
    }
    if(currentBlock.instructions.count > 0)
    [basicBlocks addObject:currentBlock];

    NSMutableArray *functions = [[NSMutableArray alloc] init];
    ScriptFunction *func = [[ScriptFunction alloc] init];
    for(BasicBlock *block in basicBlocks) {
        if([block.instructions.firstObject isKindOfClass:[EntryPointInstr class]]) {
            func = [[ScriptFunction alloc] init];
            func.basic_blocks = [[NSMutableArray alloc] init];
            [functions addObject:func];
        }
//        } else {
//            NSLog(@"Test");
//        }
        [func.basic_blocks addObject:block];
        block.function = func;
    }
    
    thread.functions = functions;
    
    
//    for(BasicBlock *block in basicBlocks)
//    {
//        NSArray *ins = [block ins];
//        for(Instr *i in ins)
//        {
//            [[[i basic_block] outs] addObject:block];
//        }
//    }
//    for(int i=1;i<basicBlocks.count; i++)
//    {
//        if([[[basicBlocks[i] instructions] firstObject] opcode] != 45)
//        {
//            [[basicBlocks[i] ins] addObject:[basicBlocks[i-1] instructions].firstObject ];
//            [[basicBlocks[i-1] outs] addObject:basicBlocks[i]];
//        }
//    }
//    
//    for(int i=0;i<basicBlocks.count-1; i++)
//    {
//        BasicBlock *block = basicBlocks[i];
//        if(block.outs.count == 1)
//        {
//            BasicBlock *targetBlock = [block.outs firstObject];
//            if([[targetBlock ins] count] == 1)
//            {
//                [block.outs removeAllObjects];
//                [block.instructions addObjectsFromArray:targetBlock.instructions];
//                [basicBlocks removeObjectAtIndex:i+1];
//                i=0;
//                continue;
//            }
//        }
//    }
//    
    NSMutableDictionary *result = [input mutableCopy];
    [result setObject:basicBlocks forKey:@"blocks"];
    
    NSMutableString *string = [@"" mutableCopy];
    for(BasicBlock *basic_block in basicBlocks)
    {
        //NSMutableDictionary *offsetMap = [[NSMutableDictionary alloc] initWithCapacity:[basic_block.instructions count]];
        [string appendFormat:@"loc_%d (%lu INS)\n", [([basic_block instructions][0]) offset], (unsigned long)basic_block.ins.count];
        for(Instr *instr in [basic_block instructions])
        {
            [string appendFormat:@"%@ (%u)\n", [instr description], [instr offset]];
            //[offsetMap setObject:instr forKey:@(instr.offset)];
        }
        //basic_block.offsetMap = offsetMap.copy;
        [string appendString:@"\n"];
    }
    [result setObject:string forKey:@"unfolded_string"];
    
    
    //result = [self foldInstructions:result];
    return result;
}

-(NSDictionary*)disassemble:(VMThread*)thread
{
    int index=0;
    int length = self.xscFile->code_length;
    Byte *code = self.xscFile->code->data;
    
    
    NSMutableString *codeStr = [[NSMutableString alloc] init];
    NSMutableArray *instructions = [[NSMutableArray alloc] init];
    while(index < length)
    {
        NSUInteger opcode = code[index];
//        if(opcode >= 127)
//        {
//            opcode = 0;
//            index++;
//            continue;
//        }
        Class instrClass = RSVM.opcodes[opcode];
        if(instrClass != nil)
        {
            
            Instr *instruction = [instrClass alloc];
            instruction.offset = index;
//            if([instruction respondsToSelector:@selector(initWithBytes::)])
//            {
                instruction = [instruction initWithBytes:&(code[index]) thread:thread];
//            }
            if(instruction.name != nil)
            {
                [codeStr appendFormat:@"%@\n", [instruction description]];
            }
            else
                NSLog(@"Instruction not found %d", opcode);
            index += instruction.size;

            [instructions addObject:instruction];
//            if(instruction.opcode == 0x55) {
//                SInt16 jmpOffset = ((Jump*)instruction).imm;
//                if(jmpOffset > 0)
//                index += jmpOffset;
//            }
        }
       
    }
    
    NSDictionary *dic = @{@"code":instructions, @"text":codeStr};
    NSDictionary *result = [self generateBasicBlocks:dic thread:thread];
    
    return result;
}
-(void)loadHeader
{
    
}
@end
