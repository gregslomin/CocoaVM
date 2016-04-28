//
//  XSCFile.h
//  cocoavm
//
//  Created by Greg Slomin on 8/9/14.
//  Copyright (c) 2014 Greg Slomin. All rights reserved.
//

#ifndef __cocoavm__XSCFile__
#define __cocoavm__XSCFile__


#define read_offset(x, rcs) (CFSwapInt32(x) & 0xFFFFFF) + rcs;
#define read_ysc_offset(x, rcs) ( x & 0xFFFFFF ) + rcs;

@class XSCDisassembler;
class PagedData
{
    
public:
    Byte *data;
    NSUInteger length;
    NSUInteger pages;
    PagedData(Byte *inBuffer, UInt32 size, UInt32 offset, int pageSize=0x4000, UInt32 rcsOffset=0, bool ysc=false)
    {
        ReadPagedDataFromOffset(inBuffer, size, offset, 0x4000, rcsOffset, ysc);
    }
    
    PagedData() {}
    
    void ReadPagedDataFromOffset(Byte* buffer, UInt32 size, UInt32 offset, UInt32 divisor = 0x4000, UInt32 rcsOffset=0, bool ysc=false);
};

class FakePagedData : public PagedData
{
    
public:
    FakePagedData(UInt32 size)
    {
        data = new Byte[size];
        memset(data, 0, size);
        length = size;
        pages = size / 0x4000 + ((size % 0x4000) ? 1 : 0);
    }
    
    void ReadPagedDataFromOffset(Byte* buffer, UInt32 size, UInt32 offset, UInt32 divisor = 0x4000, UInt32 rcsOffset=0, bool ysc=false);
};

class StringTable : public PagedData
{
public:
    StringTable(Byte *inBuffer, UInt32 size, UInt32 offset, int pageSize=0x4000, UInt32 rcsOffset=0, bool ysc=false) : PagedData(inBuffer, size, offset, 0x4000, rcsOffset, ysc)
    {
        extractStrings();
    }
    NSMutableArray *stringArray;
    void extractStrings();
    
};
class XSCFile
{
public:
    UInt32 VTable ; //just makes them properties, nothing more.
    UInt32 subheader ;
    UInt32 code_blocks_offset ;
    UInt32 globals_version ;
    UInt32 code_length ;
    UInt32 parameter_count ;
    UInt32 statics_count ;
    UInt32 globals_count ;
    UInt32 natives_count ;
    UInt32 statics_offset ;
    UInt32 globals_offset ;
    UInt32 natives_table ;
    UInt32 null4 ;
    UInt32 null5 ;
    UInt32 crc ;
    UInt32 string_block_count ;
    UInt32 script_name_offset ;
    UInt32 strings_offset ;
    UInt32 strings_size ;
    UInt32 null6 ;
    PagedData *code;
    PagedData *globals;
    StringTable *strings;
    UInt64 *natives;
    UInt32 *statics;
    bool isRSC7 ;
    
    virtual void loadData(Byte *data, XSCDisassembler* disassembler);
};

class YSCFile : public XSCFile
{
    void loadData(Byte *data, XSCDisassembler *disassembler);
};
#endif /* defined(__cocoavm__XSCFile__) */
