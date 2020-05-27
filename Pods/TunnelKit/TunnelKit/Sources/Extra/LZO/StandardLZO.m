//
//  StandardLZO.m
//  TunnelKit
//
//  Created by Davide De Rosa on 3/18/19.
//  Copyright (c) 2020 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

#import "minilzo.h"

#import "LZO.h"
#import "Errors.h"

#define HEAP_ALLOC(var,size) \
lzo_align_t __LZO_MMODEL var [ ((size) + (sizeof(lzo_align_t) - 1)) / sizeof(lzo_align_t) ]

#define LZO1X_1_15_MEM_COMPRESS ((lzo_uint32_t) (32768L * lzo_sizeof_dict_t))

static HEAP_ALLOC(wrkmem, LZO1X_1_MEM_COMPRESS);

@interface StandardLZO : NSObject <LZO>

@property (nonatomic, strong) NSMutableData *decompressedBuffer;

@end

@implementation StandardLZO

+ (NSString *)versionString
{
    return [NSString stringWithCString:lzo_version_string() encoding:NSUTF8StringEncoding];
}

- (instancetype)init
{
    if (lzo_init() != LZO_E_OK) {
        NSLog(@"LZO engine failed to initialize");
        abort();
        return nil;
    }
    if ((self = [super init])) {
        self.decompressedBuffer = [[NSMutableData alloc] initWithLength:LZO1X_1_15_MEM_COMPRESS];
    }
    return self;
}

- (NSData *)compressedDataWithData:(NSData *)data error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    const NSInteger dstBufferLength = data.length + data.length / 16 + 64 + 3;
    NSMutableData *dst = [[NSMutableData alloc] initWithLength:dstBufferLength];
    lzo_uint dstLength;
    const int status = lzo1x_1_compress(data.bytes, data.length, dst.mutableBytes, &dstLength, wrkmem);
    if (status != LZO_E_OK) {
        if (error) {
            *error = TunnelKitErrorWithCode(TunnelKitErrorCodeLZO);
        }
        return nil;
    }
    if (dstLength > data.length) {
        return nil;
    }
    dst.length = dstLength;
    return dst;
}

- (NSData *)decompressedDataWithData:(NSData *)data error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [self decompressedDataWithBytes:data.bytes length:data.length error:error];
}

- (NSData *)decompressedDataWithBytes:(const uint8_t *)bytes length:(NSInteger)length error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    lzo_uint dstLength = LZO1X_1_15_MEM_COMPRESS;
    const int status = lzo1x_decompress_safe(bytes, length, self.decompressedBuffer.mutableBytes, &dstLength, NULL);
    if (status != LZO_E_OK) {
        if (error) {
            *error = TunnelKitErrorWithCode(TunnelKitErrorCodeLZO);
        }
        return nil;
    }
    return [NSData dataWithBytes:self.decompressedBuffer.bytes length:dstLength];
}

@end
