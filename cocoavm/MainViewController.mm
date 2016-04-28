//
//  MainViewController.m
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#import "MainViewController.h"
#import "NoodleLineNumberView.h"
#import "XSCDisassembler.h"
#import "XSCFile.h"
#import "RSVM.h"
#import "Operation.h"
#define LOGGING
@interface MainViewController()

@property (weak) IBOutlet NSTableColumn *firstColumn;
@property (weak) IBOutlet NSTextField *currentLine;
@property (weak) IBOutlet NSTextField *currentInstr;
@property (weak) IBOutlet NSTableColumn *stackNumbers;
@property (weak) IBOutlet NSTableColumn *stackValues;
@property (weak) IBOutlet NSTableView *stackTable;
@property (weak) IBOutlet NSTableView *staticTable;
@property (nonatomic, retain) RSVM *vm;
@property (weak) IBOutlet NSTextField *offsetField;
@property (nonatomic, retain) NSMutableDictionary *blips;
@property (nonatomic, retain) XSCDisassembler *disAsm;
@property (nonatomic, retain) NSDictionary *result;
@property (nonatomic, retain) NSMutableArray *structStack;
//@property (nonatomic, retain) NSArray *current_blocks;
//@property (nonatomic, weak) Instr* currentInstruction;
//@property (nonatomic, weak) BasicBlock *currentBlock;

@end


@implementation MainViewController
-(void)updateFields
{
    [self.stackTable reloadData];
    [self.staticTable reloadData];
    self.currentLine.stringValue = [NSString stringWithFormat:@"%ld", (long)[self.vm.main.currentInstruction offset] ];
    self.currentInstr.stringValue = [self.vm.main.currentInstruction description];
}
- (IBAction)foldedChecked:(NSButton *)sender {
    NSLog(@"%@", sender);
    if(sender.state ==0)
    {
        [self.scriptView setString:self.result[@"unfolded_string"]];
    }
    else
    {
        [self.scriptView setString:self.result[@"folded_string"]];
    }
}
- (IBAction)nextBasicBlock:(id)sender {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [self.vm.main runToOffset:[[formatter numberFromString:self.offsetField.stringValue]unsignedIntValue]];
    [self updateFields];
    
    if(self.structStack.count > 0) {
    NSError *error;
    
        NSString *str = [self printStruct:[self.structStack firstObject] withTabString:[@"" mutableCopy]];
        NSLog(@"%@", str);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.structStack.firstObject options:NSJSONWritingPrettyPrinted error:&error];
    [jsonData writeToFile:@"test.json" atomically:true];
    }

}


-(NSString*)printStruct:(NSDictionary*)s withTabString:(NSMutableString*)tabs
{

    NSMutableString *str = [[NSMutableString alloc] init];
    [str appendFormat:@"%@struct %@ { /*%@*/\n", tabs, s[@"name"], s[@"address"][@"string"]];
    NSString *newTabs = [tabs stringByAppendingString:@"\t"];
    NSMutableArray *memberArraySorted = [[s[@"members"] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                if([obj1[@"address"][@"slot"] unsignedIntegerValue] < [obj1[@"address"][@"slot"] unsignedIntegerValue])
                    return NSOrderedAscending;
                else if([obj1[@"address"][@"slot"] unsignedIntegerValue] < [obj1[@"address"][@"slot"] unsignedIntegerValue])
                        return NSOrderedDescending;
                else
                        return NSOrderedSame;
    }] mutableCopy];
    for(NSDictionary *dic in memberArraySorted) {
        NSString *type = dic[@"type"];
        if([type isEqualToString:@"ARRAY"]) {
            NSDictionary* firstObject = [dic[@"members"] firstObject];
            if([firstObject[@"type"] isEqualToString:@"ARRAY"] || [firstObject[@"type"] isEqualToString:@"struct"]) {
                continue;
            } else {
                if([(NSArray*)dic[@"members"] count] > 0) {
                    
                [str appendFormat:@"enum %@_ENUM {", dic[@"name"]];
                for(NSDictionary *obj in dic[@"members"]) {
                    [str appendFormat:@"%@", obj[@"name"]];
                    if(obj != [dic[@"members"] lastObject]) {
                        [str appendFormat:@", "];
                    }
                }
                [str appendFormat:@"};\n"];
                    
                }
                [str appendFormat:@"%@ %@[%lu];\n", firstObject[@"type"], dic[@"name"], [((NSArray*)dic[@"members"]) count]];
            }
        }else if([type isEqualToString:@"ENUM"]){
            [str appendFormat:@"%@%@ %@; /*%@*/\n", newTabs, @"var", dic[@"name"], dic[@"address"][@"string"]];
        }else if([type isEqualToString:@"STRUCT"]) {
            [str appendString:[self printStruct:dic withTabString:[newTabs mutableCopy]]];
        } else {
            [str appendFormat:@"%@%@ %@; /*%@*/\n", newTabs, dic[@"type"], dic[@"name"], dic[@"address"][@"string"]];
        }
    }
    [str appendFormat:@"%@};\n", tabs];
    return str.copy;
}
- (IBAction)nextLine:(id)sender {
    [self.vm.main step];
    [self updateFields];
}
-(NSArray*)itemsetUnlock:(NSDictionary*)params
{
    NSLog(@"Native Called");
    return @[];
}
-(NSArray*)is_string_null_or_empty:(NSDictionary*)params
{
    StringPointer *string = params[@"params"][0];
    if(string == nil)
        return @[@1];
    else if(string.string[0] == 0)
        return @[@1];
    
    return @[@0];
}

-(NSArray*)are_strings_equal:(NSDictionary*)params
{
    StringPointer *lhs = params[@"params"][0];
    StringPointer *rhs = params[@"params"][1];
    
    if([lhs isKindOfClass:[StringPointer class]] && [rhs isKindOfClass:[StringPointer class]]) {

        if(strcmp(lhs.string, rhs.string) == 0)
            return @[@1];

    }
        return @[@0];

}
uint32_t jenkinss_one_at_a_time_hash(char *key, size_t len)
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

-(void)addStruct:(NSDictionary*)params
{
//    NSDictionary *dic =  @{@"name":params[@"params"][0],
//                           @"size":params[@"params"][1],
//                           @"type":@"struct",
//                           @"address":params[@"params"][2],
//                           @"members":[[NSMutableDictionary alloc] init]};
    

    
    NSMutableDictionary *structDic = [[NSMutableDictionary alloc] init];
    [structDic setObject:@"STRUCT" forKey:@"type"];
    StringPointer *sp = params[@"params"][0];
    if([sp isKindOfClass:[StringPointer class]]) {
        [structDic setObject:[NSString stringWithUTF8String:sp.string] forKey:@"name"];
    } else if([sp isKindOfClass:[FrameAddress class]]) {
        FrameAddress *fa = (id)sp;
        id result = [self.vm.main.stack.internalStack objectAtIndex:[self.vm.main getRealIndexFromFrameOffset:fa.slot.unsignedIntegerValue]];
        if([result isKindOfClass:[StringPointer class]]) {
            [structDic setObject:[NSString stringWithUTF8String:((StringPointer*)result).string] forKey:@"name"];
        } else {
            [structDic setObject:@"failed" forKey:@"name"];
        }
    } else {
            [structDic setObject:@"failed" forKey:@"name"];
    }

    [structDic setObject:[params[@"params"][2] serialize] forKey:@"address"];
    [structDic setObject:params[@"params"][1] forKey:@"size"];
    [structDic setObject:[[NSMutableArray alloc]init] forKey:@"members"];
    
    //[self.structStack addObject:structDic];
    [self.structStack.lastObject[@"members"] addObject:structDic];
    
    //    [((StructDef*)self.structStack.lastObject).members setObject:structDef forKey:structDef.name];
    //    [self.structStack addObject:structDef];
    [self.structStack addObject:structDic];
    
}

-(void)addArray:(NSDictionary*)params
{
//    StructDef *structDef = [[StructDef alloc] init];
//    structDef.name = params[@"params"][0];
//    structDef.address = [params[@"params"][2] copy];
//    structDef.size = params[@"params"][1];
//    structDef.type = @"ARRAY";
    
    NSMutableDictionary *structDic = [[NSMutableDictionary alloc] init];
    [structDic setObject:@"ARRAY" forKey:@"type"];
      StringPointer *sp = params[@"params"][0];
    [structDic setObject:[NSString stringWithUTF8String:sp.string] forKey:@"name"];
    [structDic setObject:[params[@"params"][2] serialize] forKey:@"address"];
    [structDic setObject:params[@"params"][1] forKey:@"size"];
    [structDic setObject:[[NSMutableArray alloc]init] forKey:@"members"];
    [structDic setObject:[[NSMutableArray alloc] init] forKey:@"enum"];
    //[self.structStack addObject:structDic];
    [self.structStack.lastObject[@"members"] addObject:structDic];
    
//    [((StructDef*)self.structStack.lastObject).members setObject:structDef forKey:structDef.name];
//    [self.structStack addObject:structDef];
    [self.structStack addObject:structDic];
    
}
-(void)addMember:(NSDictionary*)params withType:(NSString*)type
{
    StringPointer *sp = params[@"params"][0];
    NSDictionary *dic =  @{@"name":[NSString stringWithUTF8String:sp.string],
                           @"type":type,
                           @"address":[params[@"params"][1] serialize]};
    
    [self.structStack.lastObject[@"members"] addObject:dic];
    
}
-(NSArray*)get_index_of_current_level:(NSDictionary*)params
{
    return @[@(1)];
}

-(NSArray*)get_interior_at_coords:(NSDictionary*)params
{
    return @[@(0x14734104)];
}

-(NSArray*)get_hash_key:(NSDictionary*)params
{
    StringPointer *lhs = params[@"params"][0];
    return @[@(jenkinss_one_at_a_time_hash(lhs.string, strlen(lhs.string)))];
}

-(NSArray*)is_bit_set:(NSDictionary*)params
{

    NSNumber *val = params[@"params"][1];
    NSNumber *index = params[@"params"][0];
    return @[@((val.unsignedIntValue & (1<<index.unsignedIntValue)) == 1)];
}

-(NSArray*)does_blip_exist:(NSDictionary*)params
{
    
    NSNumber *index = params[@"params"][0];
    return @[@0];//[self.blips objectForKey:index];
}

-(NSArray*)floor:(NSDictionary*)params
{
    
    NSNumber *val = params[@"params"][0];
    return @[@(floorf(val.floatValue))];//[self.blips objectForKey:index];
}

-(NSArray*)stat_set_int:(NSDictionary*)params
{
    
   // NSNumber *index = params[@"params"][0];
    return @[@1];//[self.blips objectForKey:index];
}

-(NSArray*)player_ped_id:(NSDictionary*)params
{
    
   // NSNumber *index = params[@"params"][0];
    return @[@1];//[self.blips objectForKey:index];
}

-(NSArray*)is_ped_injured:(NSDictionary*)params
{
    
    //NSNumber *index = params[@"params"][0];
    return @[@0];//[self.blips objectForKey:index];
}



-(NSArray*)get_clock_seconds:(NSDictionary*)params
{
    
   // NSNumber *index = params[@"params"][0];
    return @[@59];//[self.blips objectForKey:index];
}

-(NSArray*)get_clock_hours:(NSDictionary*)params
{
    
   // NSNumber *index = params[@"params"][0];
    return @[@23];//[self.blips objectForKey:index];
}

-(NSArray*)get_clock_minutes:(NSDictionary*)params
{
    
   // NSNumber *index = params[@"params"][0];
    return @[@58];//[self.blips objectForKey:index];
}

-(NSArray*)get_clock_month:(NSDictionary*)params
{
    
    //NSNumber *index = params[@"params"][0];
    return @[@11];//[self.blips objectForKey:index];
}

-(NSArray*)get_clock_day_of_month:(NSDictionary*)params
{
    
    //NSNumber *index = params[@"params"][0];
    return @[@6];//[self.blips objectForKey:index];
}

-(NSArray*)get_clock_year:(NSDictionary*)params
{
    
    // NSNumber *index = params[@"params"][0];
    return @[@2015];//[self.blips objectForKey:index];
}

-(NSArray*)register_save_house:(NSDictionary*)params
{
    
    //NSLog(@"Register Save House: \n%@", params);
    // NSNumber *index = params[@"params"][0];
    return @[@1];//[self.blips objectForKey:index];
}

-(NSArray*)register_bool_to_save:(NSDictionary*)params
{
    
#ifdef LOGGING
    NSLog(@"BOOL: \n%@", params);
#endif
    [self addMember:params withType:@"BOOL"];
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}
-(NSArray*)register_int_to_save:(NSDictionary*)params
{
    
#ifdef LOGGING
    NSLog(@"INT: \n%@", params);
#endif
    [self addMember:params withType:@"INT"];
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)register_float_to_save:(NSDictionary*)params
{
#ifdef LOGGING
    NSLog(@"FLOAT: \n%@", params);
#endif
    [self addMember:params withType:@"FLOAT"];
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)register_enum_to_save:(NSDictionary*)params
{
#ifdef LOGGING
    NSLog(@"ENUM: \n%@", params);
#endif
    NSDictionary *obj = self.structStack.lastObject;
    if([obj[@"type"] isEqualToString:@"ARRAY"]) {
        StringPointer *str = params[@"params"][0];
        [obj[@"enum"] addObject:[NSString stringWithUTF8String:str.string]];
    } else
        [self addMember:params withType:@"ENUM"];
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)register_text_label_to_save:(NSDictionary*)params
{
    
    [self addMember:params withType:@"LABEL"];
#ifdef LOGGING
    NSLog(@"TEXT_LABEL: \n%@", params);
#endif
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)start_save_struct:(NSDictionary*)params
{
    
#ifdef LOGGING
    NSLog(@"START_STRUCT: \n%@", params);
#endif
    [self addStruct:params];
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)native_wait:(NSDictionary*)params
{
    
    //NSLog(@"START_STRUCT: \n%@", params);
    //NSLog(@"%@", params);
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)start_save_data:(NSDictionary*)params
{
//    StructDef *structDef = [[StructDef alloc] init];
//    structDef.name = @"g_SaveData";
//    structDef.address = [params[@"params"][2] copy];
//    structDef.size = params[@"params"][1];
//    structDef.type = @"STRUCT";
//    
//    [((StructDef*)self.structStack.lastObject).members setObject:structDef forKey:structDef.name];
    
    NSMutableDictionary *structDic = [[NSMutableDictionary alloc] init];
    [structDic setObject:@"STRUCT" forKey:@"type"];
    [structDic setObject:@"g_SaveData" forKey:@"name"];
    [structDic setObject:[params[@"params"][2] serialize] forKey:@"address"];
    [structDic setObject:params[@"params"][1] forKey:@"size"];
    [structDic setObject:[[NSMutableArray alloc]init] forKey:@"members"];
    [self.structStack addObject:structDic];

//    NSDictionary *dic =  @{@"name":@"g_SaveData", @"address":params[@"params"][2], @"members":@{}};
//    [self.structStack addObject:dic];
//        [self.structStack addObject:dic[@"members"]];
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)stop_save_struct:(NSDictionary*)params
{
#ifdef LOGGING
    NSLog(@"STOP_STRUCT: \n%@", params);
#endif
    //NSLog(@"%@", [self.structStack.lastObject description]);
    [self.structStack removeLastObject];
    // NSNumber *index = params[@"params"][0];

    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)start_save_array:(NSDictionary*)params
{
    
    [self addArray:params];
#ifdef LOGGING
    NSLog(@"START_ARRAY: \n%@", params);
#endif
    // NSNumber *index = params[@"params"][0];
    GlobalAddress *addr = params[@"params"][2];
//    if([addr isKindOfClass:[GlobalAddress class]]) {
//        uint64_t * temp = (uint64_t*)&(self.vm.globals[addr.slot.unsignedLongValue]);
//        NSNumber *count = params[@"params"][1];
//        *temp = count.unsignedLongValue;
//    } else {
//        NSLog(@"WTF not a global?");
//    }
    return @[];//[self.blips objectForKey:index];
}

-(NSArray*)stop_save_array:(NSDictionary*)params
{
    
#ifdef LOGGING
    NSLog(@"STOP_ARRAY: \n%@", params);
#endif
    [self.structStack removeLastObject];
    //    NSLog(@"%@", [self.structStack.lastObject description]);
    // NSNumber *index = params[@"params"][0];
    return @[];//[self.blips objectForKey:index];
}
-(NSArray*)set_bit:(NSDictionary*)params
{
    id address = params[@"params"][1];
    NSNumber *index = params[@"params"][0];
    if([address isKindOfClass:[GlobalAddress class]])
    {
        UInt32 *val = (UInt32*)((GlobalAddress*)address).address;
        *val |= 1 << index.unsignedIntValue;
    }
    return @[];
}

-(NSArray*)random_int_in_range:(NSDictionary*)params
{
    NSNumber *max = params[@"params"][0];
    NSNumber *min = params[@"params"][1];
    int range = max.unsignedIntegerValue - min.unsignedIntegerValue;
    int val = (rand()%range)+min.unsignedIntegerValue;
    return @[@(val)];
}

-(NSArray*)shift_left:(NSDictionary*)params
{
    id address = params[@"params"][1];
    NSNumber *index = params[@"params"][0];
    if([address isKindOfClass:[GlobalAddress class]])
    {
        UInt32 *val = (UInt32*)((GlobalAddress*)address).address;
        *val = *val << index.unsignedIntegerValue;// 1 << index.unsignedIntValue;
        return @[@(*val)];
    }
    return @[@0];
}

-(NSArray*)to_float:(NSDictionary*)params
{
        NSNumber *val = params[@"params"][0];

    return @[@(val.floatValue)];
}

-(NSArray*)shift_right:(NSDictionary*)params
{
    id address = params[@"params"][1];
    NSNumber *index = params[@"params"][0];
    if([address isKindOfClass:[GlobalAddress class]])
    {
        UInt32 *val = (UInt32*)((GlobalAddress*)address).address;
        *val = *val >> index.unsignedIntegerValue;// 1 << index.unsignedIntValue;
        return @[@(*val)];
    }
    return @[@0];
}
-(NSArray*)native_stub_return_zero:(NSDictionary*)params
{
    return @[@0];
}

-(NSArray*)native_stub_return_one:(NSDictionary*)params
{
    return @[@1];
}
-(void)awakeFromNib
{
    self.structStack = [[NSMutableArray alloc] init];
    self.blips = [[NSMutableDictionary alloc] init];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"patched_charanimtest" ofType:@"ysc"];
    self.vm = [RSVM sharedInstance];
    [self.vm setStartupScript:[NSData dataWithContentsOfFile:path] withExtension:@"ysc"];
    self.lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:self.scrollView];
    
    
    [self.scrollView setVerticalRulerView:self.lineNumberView];
    [self.scrollView setHasHorizontalRuler:NO];
    [self.scrollView setHasVerticalRuler:YES];
    [self.scrollView setRulersVisible:YES];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"updateFields" object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self updateFields];
    }];
        [self.scriptView setString:self.vm.main.disAsm[@"unfolded_string"]];

//    [self updateFields];
    [self.vm registerNative:@"get_itemset_with_unlock" selector:@selector(itemsetUnlock:) sender:self];
    [self.vm registerNative:@"get_index_of_current_level" selector:@selector(get_index_of_current_level:) sender:self];
    [self.vm registerNative:@"set_bit" selector:@selector(set_bit:) sender:self];
    [self.vm registerNative:@"is_bit_set" selector:@selector(is_bit_set:) sender:self];
    [self.vm registerNative:@"does_blip_exist" selector:@selector(does_blip_exist:) sender:self];
        [self.vm registerNative:@"is_string_null_or_empty" selector:@selector(is_string_null_or_empty:) sender:self];
    [self.vm registerNative:@"are_strings_equal" selector:@selector(are_strings_equal:) sender:self];
        [self.vm registerNative:@"shift_left" selector:@selector(shift_left:) sender:self];
    
    //get_hash_key
    [self.vm registerNative:@"get_hash_key" selector:@selector(get_hash_key:) sender:self];
    [self.vm registerNative:@"get_interior_at_coords" selector:@selector(get_interior_at_coords:) sender:self];
    [self.vm registerNative:@"floor" selector:@selector(floor:) sender:self];
    [self.vm registerNative:@"stat_set_int" selector:@selector(stat_set_int:) sender:self];
        [self.vm registerNative:@"stat_set_float" selector:@selector(stat_set_int:) sender:self];
        [self.vm registerNative:@"stat_set_bool" selector:@selector(stat_set_int:) sender:self];
    [self.vm registerNative:@"player_ped_id" selector:@selector(player_ped_id:) sender:self];
    [self.vm registerNative:@"is_ped_injured" selector:@selector(is_ped_injured:) sender:self];
    [self.vm registerNative:@"does_entity_exist" selector:@selector(native_stub_return_zero:) sender:self];
    
    [self.vm registerNative:@"wait" selector:@selector(native_wait:) sender:self];
    [self.vm registerNative:@"shift_right" selector:@selector(shift_right:) sender:self];
    [self.vm registerNative:@"get_clock_seconds" selector:@selector(get_clock_seconds:) sender:self];
    [self.vm registerNative:@"get_clock_hours" selector:@selector(get_clock_hours:) sender:self];
    [self.vm registerNative:@"get_clock_minutes" selector:@selector(get_clock_minutes:) sender:self];
    [self.vm registerNative:@"get_clock_month" selector:@selector(get_clock_month:) sender:self];
    [self.vm registerNative:@"get_clock_day_of_month" selector:@selector(get_clock_day_of_month:) sender:self];
    [self.vm registerNative:@"get_clock_year" selector:@selector(get_clock_year:) sender:self];
    [self.vm registerNative:@"register_save_house" selector:@selector(register_save_house:) sender:self];
    [self.vm registerUnknownNative:0xFB45728E selector:@selector(start_save_struct:) sender:self];
    [self.vm registerNative:@"stop_save_struct" selector:@selector(stop_save_struct:) sender:self];
        [self.vm registerNative:@"start_save_data" selector:@selector(start_save_data:) sender:self];
    [self.vm registerUnknownNative:0x893A342C selector:@selector(start_save_array:) sender:self];
    [self.vm registerNative:@"stop_save_array" selector:@selector(stop_save_array:) sender:self];
    [self.vm registerNative:@"register_enum_to_save" selector:@selector(register_enum_to_save:) sender:self];
    [self.vm registerNative:@"register_int_to_save" selector:@selector(register_int_to_save:) sender:self];
    [self.vm registerNative:@"register_float_to_save" selector:@selector(register_float_to_save:) sender:self];
    [self.vm registerNative:@"register_bool_to_save" selector:@selector(register_bool_to_save:) sender:self];
    [self.vm registerNative:@"register_text_label_to_save" selector:@selector(register_text_label_to_save:) sender:self];
    [self.vm registerUnknownNative:0x9ef0bc64 selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerUnknownNative:0x06396058 selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerUnknownNative:0xD87F3A9E selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerUnknownNative:0x106C8317 selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerUnknownNative:0x5afcd8a1 selector:@selector(native_stub_return_zero:) sender:self];
        [self.vm registerUnknownNative:0x29d3841 selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerUnknownNative:0x67116627 selector:@selector(to_float:) sender:self];
    [self.vm registerNative:@"is_entity_dead" selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerNative:@"is_dlc_present" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_ammo_in_ped_weapon" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_ped_weapontype_in_slot" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"has_ped_got_weapon" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_dlc_weapon_data" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"has_ped_got_weapon_component" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_dlc_weapon_component_data" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_current_ped_weapon" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_num_dlc_weapons" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"add_stunt_jump_angled" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"add_stunt_jump" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"is_player_playing" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"is_ped_being_arrested" selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerNative:@"is_xbox360_version" selector:@selector(native_stub_return_zero:) sender:self];
        [self.vm registerNative:@"network_is_game_in_progress" selector:@selector(native_stub_return_zero:) sender:self];
            [self.vm registerNative:@"network_is_cloud_available" selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerNative:@"is_ps3_version" selector:@selector(native_stub_return_one:) sender:self];
    
    [self.vm registerNative:@"get_entity_model" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"has_model_loaded" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"has_script_loaded" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"start_new_script" selector:@selector(native_stub_return_one:) sender:self];
        [self.vm registerNative:@"stat_get_int" selector:@selector(native_stub_return_one:) sender:self];
            [self.vm registerNative:@"is_scenario_group_enabled" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"is_player_being_arrested" selector:@selector(native_stub_return_zero:) sender:self];
    [self.vm registerNative:@"is_player_control_on" selector:@selector(native_stub_return_one:) sender:self];
    [self.vm registerNative:@"get_random_int_in_range" selector:@selector(random_int_in_range:) sender:self];
    
    
    
    
    [self.vm registerUnknownNative:0x5DCD0796 selector:@selector(native_stub_return_zero:) sender:self];
    
    
    
    

}
-(id)count {
    return @0;
}
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if(tableView == self.stackTable)
    {
        return [[[self vm].main stack] count];
    }
    else
    {
        if(self.vm.main.statics == nil)
            return 0;
        
        return [[[self vm].main statics] count];
    }
    return 0;
}

-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if(tableView == self.stackTable)
    {
         NSTextField *result = [tableView makeViewWithIdentifier:@"columnOne" owner:self];
        if (result == nil) {
            
            
            NSRect rect;
            rect.origin.x = 0;
            rect.origin.y = 0;
            rect.size.width = 100;
            rect.size.height = 20;
            result = [[NSTextField alloc] initWithFrame:rect];
            result.identifier = @"MyView";
        }
        if(tableColumn == self.stackNumbers)
        {
                    int frameIndex = self.vm.main.stack.internalStack.count - self.vm.main.framePointer;
            int index = row-frameIndex;
            if(index == -1 && false ) // self.vm.main.callStack.internalStack.count != 1)
                result.stringValue = @"Ret";
            else if(index >= 0)
            {
                result.stringValue = [NSString stringWithFormat:@"FP+%d", (index)];

            }
            else
            {
                if(self.vm.main.callStack.internalStack.count == 1)
                    index++;
                else
                    index+=2;
                result.stringValue = [NSString stringWithFormat:@"SP+%d", ((-index))];
                
            }
            
                   }
        else
        {
            NSUInteger index = self.vm.main.stack.count - (row+1);
            NSNumber *number = self.vm.main.stack.internalStack[index];
            result.stringValue = [NSString stringWithFormat:@"%@", number];
        }
        return result;
    }
    NSTextField *result = [tableView makeViewWithIdentifier:@"columnOne" owner:self];
    if (result == nil) {
        
        NSRect rect;
        rect.origin.x = 0;
        rect.origin.y = 0;
        rect.size.width = 100;
        rect.size.height = 20;
        result = [[NSTextField alloc] initWithFrame:rect];
        result.identifier = @"MyView";
    }
    if(tableColumn == self.firstColumn)
    {

        result.stringValue = [NSString stringWithFormat:@"%ld", (long)row];
    }
    else
    {
        
        id val = [self vm].main.statics[row];
        result.stringValue = [NSString stringWithFormat:@"%@", val];
    }
    return result;
}

@end

@implementation StructDef

-(id)init {
    self = [super init];
    if(self) {
        self.members = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(NSDictionary*)getDic
{
   return @{@"name":self.name, @"size":self.size, @"type":self.type, @"address":self.address, @"members":self.members};
}
-(NSString*)description {
    return [[self getDic] description];
}
-(NSData*)getJSON
{
    return  [NSJSONSerialization dataWithJSONObject:self.members options:1 error:nil];
}
@end
