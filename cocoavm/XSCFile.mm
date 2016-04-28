
//
//  XSCFile.cpp
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#include "XSCFile.h"
#include "XSCDisassembler.h"

void PagedData::ReadPagedDataFromOffset(Byte* buffer, UInt32 size, UInt32 offset, UInt32 divisor, UInt32 rcsOffset, bool ysc)
{
    UInt32 block_count = 0;
    if (size > divisor)
        block_count = size / divisor + (UInt32)(((size % divisor) > 0) ? 1 : 0);
    else if (size > 0)
        block_count = 1;
    else
        return;
    
    pages = block_count;
    this->length = size;
    UInt32 *block_offsets = new UInt32[block_count];
    
    UInt32 *offsetPointer = (UInt32*)&(buffer[offset]);
    UInt64 *offsetPointer64 = (UInt64*)&(buffer[offset]);
    if(false){//block_count == 1) {
        block_offsets[0] = offset+0x10;
    } else {
        for (int i = 0; i < block_count; i++)
        {
            if(ysc) {
                block_offsets[i] = read_ysc_offset(offsetPointer64[i], rcsOffset);
            } else {
                block_offsets[i] = read_offset(offsetPointer[i], rcsOffset);
            }
        }
    }
    
    data = new Byte[0x4000*block_count];
    
    for (int i = 0; i < block_count; i++)
    {
        UInt32 readSize = 0;
        if (i == (block_count - 1))
            readSize = size % divisor;
        else
            readSize = divisor;
        
        UInt32 offset = block_offsets[i];
        //reader.BaseStream.Seek(getOffset(block_offsets[i]), 0);
        Byte *block = (Byte*)&buffer[offset];
        //            reader.Read(buffer, i * (int)divisor, (int)readSize);
        memcpy(data+i*0x4000, block, readSize);
    }
}
void StringTable::extractStrings()
{
    stringArray = [[NSMutableArray alloc] init];
    Byte *stringData = this->data;
    int start=0;
    int length=0;
    
    for(int i=0; i<this->length; i++)
    {
        if(stringData[i] == 0)
        {
            length = i-start;
            Byte *string = new Byte[length+1];
            memcpy(string, stringData, length+1);
            NSString *stringToAdd = [NSString stringWithUTF8String:(const char*)&(stringData[start])];
            [stringArray addObject:stringToAdd];
            start += length+1;
        }
    }
}
#define FAKE_GLOBALS 1

void XSCFile::loadData(Byte *data, XSCDisassembler *disassembler)
{
    
    UInt32 rcsOffset = 0;
    Byte *temp = &(data[rcsOffset]);
    UInt32 *header = (UInt32*)temp;
    UInt32 rscCheck = CFSwapInt32(header[0]);
    if(rscCheck == 1381188407)
    {
        rcsOffset = 0x10;
        header = (UInt32*)(&(data[rcsOffset]));
    }
    
    VTable = CFSwapInt32(header[0]);
    subheader = read_offset(header[1], rcsOffset);
    code_blocks_offset = read_offset(header[2], rcsOffset);
    globals_version = CFSwapInt32(header[3]);
    code_length = CFSwapInt32(header[4]);
    parameter_count = CFSwapInt32(header[5]);
    statics_count = CFSwapInt32(header[6]);
#ifdef FAKE_GLOBALS
    globals_count = 117629*24;
#else
    globals_count = CFSwapInt32(header[7]);
#endif
    natives_count = CFSwapInt32(header[8]);
    statics_offset = read_offset(header[9], rcsOffset);
    globals_offset = read_offset(header[10], rcsOffset);
    
    natives_table = read_offset(header[11], rcsOffset);
    null4 = CFSwapInt32(header[12]);
    null5 = CFSwapInt32(header[13]);
    crc = CFSwapInt32(header[14]);
    string_block_count = CFSwapInt32(header[15]);
    script_name_offset = read_offset(header[16], rcsOffset);
    strings_offset = read_offset(header[17], rcsOffset);
    strings_size = CFSwapInt32(header[18]);
    null6 = CFSwapInt32(header[19]);
#ifdef FAKE_GLOBALS
    globals = new FakePagedData(117629*8);
#else
    globals = new PagedData(data, globals_count, globals_offset, 0x4000, rcsOffset);
#endif
    code = new PagedData(data, code_length, code_blocks_offset, 0x4000, rcsOffset);
    strings = new StringTable(data, strings_size, strings_offset, 0x4000, rcsOffset);
    natives = new UInt64[natives_count];
    UInt32 *natives_start = (UInt32*)(&(data[natives_table]));
    NSDictionary *global_natives = [XSCDisassembler natives];
    NSMutableDictionary *matched_natives = [[NSMutableDictionary alloc] init];
    for(int i=0; i<natives_count; i++)
    {
        natives[i] = CFSwapInt32(natives_start[i]);
        NSString *result = global_natives[@(natives[i])];
        if(result == nil)
        {
            result = @"Native";
        }
        [matched_natives setObject:result forKey:@(i)];
        
    }
    UInt32* statics_start = (UInt32*)(&(data[statics_offset]));
    statics = new UInt32[statics_count];
    for(int i=0; i<statics_count; i++)
    {
        statics[i] = CFSwapInt32(statics_start[i]);
    }
    NSLog(@"Done loading script file");
}
/*struct ysc_header {
 uint64 vtable;
 uint64 subheader;
 uint64 code_blocks_offset;
 uint32 globals_version; // globals version?
 uint32 code_size; // code length?
 uint32 param_count;
 uint32 statics_Size;
 uint32 globals_size;
 uint32 natives_size;
 uint64 statics_offset;
 uint64 globals_offset;
 uint64 natives_offset;
 uint64 null;
 uint64 null;
 uint32 script_name_hash;
 uint32 string_blocks_count;
 uint64 script_name_offset;
 uint64 string_table_offset;
 uint64 string_table_size;
 code_blocks_offset = 0;
 } HEADER;*/


UInt64 get64(Byte *buf) {
    return *((UInt64*)buf);
}

UInt32 get32(Byte *buf) {
    return *((UInt32*)buf);
}

inline uint64_t rotl64 ( uint64_t x, uint64_t r )
{
    r = r%64;
    
    return (x << r) | (x >> (64 - r));
}


void YSCFile::loadData(Byte *data, XSCDisassembler *disassembler)
{
    
    UInt32 rcsOffset = 0;
    Byte *temp = &(data[rcsOffset]);
    UInt32 *header = (UInt32*)temp;
    UInt32 rscCheck = CFSwapInt32(header[0]);
    if(rscCheck == 1381188407)
    {
        rcsOffset = 0x10;
        header = (UInt32*)(&(data[rcsOffset]));
    }
    
    VTable = get64(temp+0);
    subheader = get64(temp+8);
    code_blocks_offset = read_ysc_offset(get64(temp+16), rcsOffset);//read_offset(header[2], rcsOffset);
    globals_version = get32(temp+24);//CFSwapInt32(header[3]);
    code_length = get32(temp+28);//CFSwapInt32(header[4]);
    parameter_count = get32(temp+32);//CFSwapInt32(header[5]);
    statics_count = get32(temp+36);//CFSwapInt32(header[6]);
#ifdef FAKE_GLOBALS
    globals_count = 117629*4;
#else
    globals_count = get32(temp+40);//CFSwapInt32(header[7]);
#endif
    natives_count = get32(temp+44);//CFSwapInt32(header[8]);
    statics_offset = read_ysc_offset(get64(temp+48), rcsOffset);//read_offset(header[9], rcsOffset);
    globals_offset = read_ysc_offset(get64(temp+56), rcsOffset);//read_offset(header[10], rcsOffset);
    
    natives_table = read_ysc_offset(get64(temp+64), rcsOffset);
    null4 = get64(temp+72);//CFSwapInt32(header[12]);
    null5 = get64(temp+80);//CFSwapInt32(header[13]);
    crc = get32(temp+88);//CFSwapInt32(header[14]);
    string_block_count = get32(temp+92);//CFSwapInt32(header[15]);
    script_name_offset = read_ysc_offset(get64(temp+96), rcsOffset);
    strings_offset = read_ysc_offset(get64(temp+104), rcsOffset);
    strings_size = get64(temp+112);//(header[18]);
    null6 = 0;//CFSwapInt32(header[19]);
#ifdef FAKE_GLOBALS
    globals = new FakePagedData(200000*8);
#else
    globals = new PagedData(data, globals_count, globals_offset, 0x4000, rcsOffset, true);
#endif
    code = new PagedData(data, code_length, code_blocks_offset, 0x4000, rcsOffset, true);
    strings = new StringTable(data, strings_size, strings_offset, 0x4000, rcsOffset, true);
    natives = new UInt64[natives_count];
    UInt64 *natives_start = (UInt64*)(&(data[natives_table]));
    NSDictionary *global_natives = [XSCDisassembler natives];
    NSMutableDictionary *matched_natives = [[NSMutableDictionary alloc] init];
    for(int i=0; i<natives_count; i++)
    {
        natives[i] = rotl64(natives_start[i], code_length+i);
        NSString *result = global_natives[@(natives[i])];
        if(result == nil)
        {
            result = @"Native";
        }
        [matched_natives setObject:result forKey:@(i)];
        
    }
    UInt32* statics_start = (UInt32*)(&(data[statics_offset]));
    statics = new UInt32[statics_count];
    for(int i=0; i<statics_count; i++)
    {
        statics[i] = CFSwapInt32(statics_start[i]);
    }
    NSLog(@"Done loading script file");
}