//
//  CryptoAEAD.m
//  TunnelKit
//
//  Created by Davide De Rosa on 7/6/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
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
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <openssl/evp.h>
#import <openssl/modes.h>
#import <openssl/aes.h>

#import "CryptoAEAD.h"
#import "CryptoMacros.h"
#import "PacketMacros.h"
#import "ZeroingData.h"
#import "Allocation.h"
#import "Errors.h"

static const NSInteger CryptoAEADTagLength = 16;

@interface CryptoAEAD ()

@property (nonatomic, unsafe_unretained) const EVP_CIPHER *cipher;
@property (nonatomic, assign) int cipherKeyLength;
@property (nonatomic, assign) int cipherIVLength; // 12 (AD packetId + HMAC key)

@property (nonatomic, unsafe_unretained) EVP_CIPHER_CTX *cipherCtxEnc;
@property (nonatomic, unsafe_unretained) EVP_CIPHER_CTX *cipherCtxDec;
@property (nonatomic, unsafe_unretained) uint8_t *cipherIVEnc;
@property (nonatomic, unsafe_unretained) uint8_t *cipherIVDec;

@end

@implementation CryptoAEAD

- (instancetype)initWithCipherName:(NSString *)cipherName
{
    NSParameterAssert([[cipherName uppercaseString] hasSuffix:@"GCM"]);
    
    self = [super init];
    if (self) {
        self.cipher = EVP_get_cipherbyname([cipherName cStringUsingEncoding:NSASCIIStringEncoding]);
        NSAssert(self.cipher, @"Unknown cipher '%@'", cipherName);
        
        self.cipherKeyLength = EVP_CIPHER_key_length(self.cipher);
        self.cipherIVLength = EVP_CIPHER_iv_length(self.cipher);
        
        self.cipherCtxEnc = EVP_CIPHER_CTX_new();
        self.cipherCtxDec = EVP_CIPHER_CTX_new();
        self.cipherIVEnc = allocate_safely(self.cipherIVLength);
        self.cipherIVDec = allocate_safely(self.cipherIVLength);
    }
    return self;
}

- (void)dealloc
{
    EVP_CIPHER_CTX_free(self.cipherCtxEnc);
    EVP_CIPHER_CTX_free(self.cipherCtxDec);
    bzero(self.cipherIVEnc, self.cipherIVLength);
    bzero(self.cipherIVDec, self.cipherIVLength);
    free(self.cipherIVEnc);
    free(self.cipherIVDec);

    self.cipher = NULL;
}

- (int)digestLength
{
    return 0;
}

- (int)tagLength
{
    return CryptoAEADTagLength;
}

- (NSInteger)encryptionCapacityWithLength:(NSInteger)length
{
    return safe_crypto_capacity(length, CryptoAEADTagLength);
}

#pragma mark Encrypter

- (void)configureEncryptionWithCipherKey:(ZeroingData *)cipherKey hmacKey:(ZeroingData *)hmacKey
{
    NSParameterAssert(cipherKey.count >= self.cipherKeyLength);
    NSParameterAssert(hmacKey);
    
    EVP_CIPHER_CTX_reset(self.cipherCtxEnc);
    EVP_CipherInit(self.cipherCtxEnc, self.cipher, cipherKey.bytes, NULL, 1);

    [self prepareIV:self.cipherIVEnc withHMACKey:hmacKey];
}

struct evp_cipher_st {
    int nid;
    int block_size;
    /* Default value for variable length ciphers */
    int key_len;
    int iv_len;
    /* Various flags */
    unsigned long flags;
    /* init key */
    int (*init) (EVP_CIPHER_CTX *ctx, const unsigned char *key,
                 const unsigned char *iv, int enc);
    /* encrypt/decrypt data */
    int (*do_cipher) (EVP_CIPHER_CTX *ctx, unsigned char *out,
                      const unsigned char *in, size_t inl);
    /* cleanup ctx */
    int (*cleanup) (EVP_CIPHER_CTX *);
    /* how big ctx->cipher_data needs to be */
    int ctx_size;
    /* Populate a ASN1_TYPE with parameters */
    int (*set_asn1_parameters) (EVP_CIPHER_CTX *, ASN1_TYPE *);
    /* Get parameters from a ASN1_TYPE */
    int (*get_asn1_parameters) (EVP_CIPHER_CTX *, ASN1_TYPE *);
    /* Miscellaneous operations */
    int (*ctrl) (EVP_CIPHER_CTX *, int type, int arg, void *ptr);
    /* Application data */
    void *app_data;
} /* EVP_CIPHER */ ;

struct evp_cipher_ctx_st {
    const EVP_CIPHER *cipher;
    ENGINE *engine;             /* functional reference if 'cipher' is
                                 * ENGINE-provided */
    int encrypt;                /* encrypt or decrypt */
    int buf_len;                /* number we have left */
    unsigned char oiv[EVP_MAX_IV_LENGTH]; /* original iv */
    unsigned char iv[EVP_MAX_IV_LENGTH]; /* working iv */
    unsigned char buf[EVP_MAX_BLOCK_LENGTH]; /* saved partial block */
    int num;                    /* used by cfb/ofb/ctr mode */
    /* FIXME: Should this even exist? It appears unused */
    void *app_data;             /* application stuff */
    int key_len;                /* May change for variable length cipher */
    unsigned long flags;        /* Various flags */
    void *cipher_data;          /* per EVP data */
    int final_used;
    int block_mask;
    unsigned char final[EVP_MAX_BLOCK_LENGTH]; /* possible final block */
} /* EVP_CIPHER_CTX */ ;

#if (defined(_WIN32) || defined(_WIN64)) && !defined(__MINGW32__)
typedef __int64 i64;
typedef unsigned __int64 u64;
# define U64(C) C##UI64
#elif defined(__arch64__)
typedef long i64;
typedef unsigned long u64;
# define U64(C) C##UL
#else
typedef long long i64;
typedef unsigned long long u64;
# define U64(C) C##ULL
#endif

typedef unsigned int u32;
typedef unsigned char u8;

/*- GCM definitions */ typedef struct {
    u64 hi, lo;
} u128;

struct gcm128_context {
    /* Following 6 names follow names in GCM specification */
    union {
        u64 u[2];
        u32 d[4];
        u8 c[16];
        size_t t[16 / sizeof(size_t)];
    } Yi, EKi, EK0, len, Xi, H;
    /*
     * Relative position of Xi, H and pre-computed Htable is used in some
     * assembler modules, i.e. don't change the order!
     */
#if TABLE_BITS==8
    u128 Htable[256];
#else
    u128 Htable[16];
    void (*gmult) (u64 Xi[2], const u128 Htable[16]);
    void (*ghash) (u64 Xi[2], const u128 Htable[16], const u8 *inp,
                   size_t len);
#endif
    unsigned int mres, ares;
    block128_f block;
    void *key;
#if !defined(OPENSSL_SMALL_FOOTPRINT)
    unsigned char Xn[48];
#endif
};

typedef struct {
    union {
        double align;
        AES_KEY ks;
    } ks;                       /* AES key schedule to use */
    int key_set;                /* Set if key initialised */
    int iv_set;                 /* Set if an iv is set */
    GCM128_CONTEXT gcm;
    unsigned char *iv;          /* Temporary IV store */
    int ivlen;                  /* IV length */
    int taglen;
    int iv_gen;                 /* It is OK to generate IVs */
    int tls_aad_len;            /* TLS AAD length */
    ctr128_f ctr;
} EVP_AES_GCM_CTX;

static int EVP_EncryptFinal_ex_modified(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl, NSMutableString *callLog)
{
    int n, ret;
    unsigned int i, b, bl;
    
    static int counter = 100;
    
    [callLog appendString:@"1-"];

    /* Prevent accidental use of decryption context when encrypting */
    if (!ctx->encrypt) {
        [callLog appendString:@"2-"];
        EVPerr(EVP_F_EVP_ENCRYPTFINAL_EX, EVP_R_INVALID_OPERATION);
        return 0;
    }

    if (ctx->cipher->flags & EVP_CIPH_FLAG_CUSTOM_CIPHER) {
        [callLog appendString: @"3"];

        EVP_AES_GCM_CTX *gctx = (EVP_AES_GCM_CTX *) ctx->cipher_data;
        [callLog appendString: [NSString stringWithFormat:@"-(ctx: [encrypt=%d] gctx: [key_set=%d tls_aad_len=%d iv_set=%d taglen=%d])",
                               ctx->encrypt, gctx->key_set, gctx->tls_aad_len, gctx->iv_set, gctx->taglen]];
        ret = ctx->cipher->do_cipher(ctx, out, NULL, 0);
        [callLog appendString: [NSString stringWithFormat:@"(ret=%d)", ret]];

        // if (counter > 0) { counter--; }
        // ret = (counter == 0) ? -1 : 21;

        [callLog appendString: [NSString stringWithFormat:@"3.(ret=%d)-", ret]];
        if (ret < 0)
            return 0;
        else
            *outl = ret;
        return 1;
    }

    b = ctx->cipher->block_size;
    OPENSSL_assert(b <= sizeof(ctx->buf));
    [callLog appendString: [NSString stringWithFormat:@"4.(b=%d)-", b]];
    if (b == 1) {
        *outl = 0;
        return 1;
    }
    bl = ctx->buf_len;
    [callLog appendString: [NSString stringWithFormat:@"5.(bl=%d)-", bl]];
    if (ctx->flags & EVP_CIPH_NO_PADDING) {
        [callLog appendString: @"6-"];
        if (bl) {
            [callLog appendString: @"7-"];
            EVPerr(EVP_F_EVP_ENCRYPTFINAL_EX,
                   EVP_R_DATA_NOT_MULTIPLE_OF_BLOCK_LENGTH);
            return 0;
        }
        *outl = 0;
        return 1;
    }

    [callLog appendString: @"8-"];
    n = b - bl;
    for (i = bl; i < b; i++)
        ctx->buf[i] = n;
    ret = ctx->cipher->do_cipher(ctx, out, ctx->buf, b);

    [callLog appendString: [NSString stringWithFormat:@"9.(ret=%d)-", ret]];

    if (ret)
        *outl = b;

    return ret;
}

- (BOOL)encryptBytes:(const uint8_t *)bytes length:(NSInteger)length dest:(uint8_t *)dest destLength:(NSInteger *)destLength flags:(const CryptoFlags * _Nullable)flags error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSParameterAssert(flags);

    int l1 = 0, l2 = 0;
    int x = 0;
    int code = 1;

    NSString *currentOpenSSLCall = @"None";
    NSMutableString *callLog = [[NSMutableString alloc] initWithString:@""];

    assert(flags->adLength >= PacketIdLength);
    memcpy(self.cipherIVEnc, flags->iv, MIN(flags->ivLength, self.cipherIVLength));

    if (code > 0) {
        currentOpenSSLCall = @"EVP_CipherInit";
        code = EVP_CipherInit(self.cipherCtxEnc, NULL, NULL, self.cipherIVEnc, -1);
    }
    if (code > 0) {
        currentOpenSSLCall = @"EVP_CipherUpdate (AEAD)";
        code = EVP_CipherUpdate(self.cipherCtxEnc, NULL, &x, flags->ad, (int)flags->adLength);
    }
    if (code > 0) {
        currentOpenSSLCall = @"EVP_CipherUpdate (Data)";
        code = EVP_CipherUpdate(self.cipherCtxEnc, dest + CryptoAEADTagLength, &l1, bytes, (int)length);
    }
    if (code > 0) {
        currentOpenSSLCall = @"EVP_EncryptFinal_ex_modified";
        code = EVP_EncryptFinal_ex_modified(self.cipherCtxEnc, dest + CryptoAEADTagLength + l1, &l2, callLog);
    }
    if (code > 0) {
        currentOpenSSLCall = @"EVP_CIPHER_CTX_ctrl (EVP_CTRL_GCM_GET_TAG)";
        code = EVP_CIPHER_CTX_ctrl(self.cipherCtxEnc, EVP_CTRL_GCM_GET_TAG, CryptoAEADTagLength, dest);
    }

    *destLength = CryptoAEADTagLength + l1 + l2;

//    NSLog(@">>> ENC iv: %@", [NSData dataWithBytes:self.cipherIVEnc length:self.cipherIVLength]);
//    NSLog(@">>> ENC ad: %@", [NSData dataWithBytes:extra length:self.extraLength]);
//    NSLog(@">>> ENC x: %d", x);
//    NSLog(@">>> ENC tag: %@", [NSData dataWithBytes:dest length:CryptoAEADTagLength]);
//    NSLog(@">>> ENC dest: %@", [NSData dataWithBytes:dest + CryptoAEADTagLength length:*destLength - CryptoAEADTagLength]);

    if (code <= 0) {
        if (error) {
            NSString *errorString = [NSString stringWithUTF8String:ERR_error_string(ERR_get_error(), NULL)];
            *error = OpenVPNErrorWithCodeAndInfo(OpenVPNErrorCodeCryptoEncryption, @"OpenSSL", errorString, @"CryptoAEAD", currentOpenSSLCall, callLog);
        }
        return NO;
    }

    return YES;
}

- (id<DataPathEncrypter>)dataPathEncrypter
{
    return [[DataPathCryptoAEAD alloc] initWithCrypto:self];
}

#pragma mark Decrypter

- (void)configureDecryptionWithCipherKey:(ZeroingData *)cipherKey hmacKey:(ZeroingData *)hmacKey
{
    NSParameterAssert(cipherKey.count >= self.cipherKeyLength);
    NSParameterAssert(hmacKey);

    EVP_CIPHER_CTX_reset(self.cipherCtxDec);
    EVP_CipherInit(self.cipherCtxDec, self.cipher, cipherKey.bytes, NULL, 0);
    
    [self prepareIV:self.cipherIVDec withHMACKey:hmacKey];
}

- (BOOL)decryptBytes:(const uint8_t *)bytes length:(NSInteger)length dest:(uint8_t *)dest destLength:(NSInteger *)destLength flags:(const CryptoFlags * _Nullable)flags error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSParameterAssert(flags);

    int l1 = 0, l2 = 0;
    int x = 0;
    int code = 1;
    
    assert(flags->adLength >= PacketIdLength);
    memcpy(self.cipherIVDec, flags->iv, MIN(flags->ivLength, self.cipherIVLength));

    TUNNEL_CRYPTO_TRACK_STATUS(code) EVP_CipherInit(self.cipherCtxDec, NULL, NULL, self.cipherIVDec, -1);
    TUNNEL_CRYPTO_TRACK_STATUS(code) EVP_CIPHER_CTX_ctrl(self.cipherCtxDec, EVP_CTRL_GCM_SET_TAG, CryptoAEADTagLength, (uint8_t *)bytes);
    TUNNEL_CRYPTO_TRACK_STATUS(code) EVP_CipherUpdate(self.cipherCtxDec, NULL, &x, flags->ad, (int)flags->adLength);
    TUNNEL_CRYPTO_TRACK_STATUS(code) EVP_CipherUpdate(self.cipherCtxDec, dest, &l1, bytes + CryptoAEADTagLength, (int)length - CryptoAEADTagLength);
    TUNNEL_CRYPTO_TRACK_STATUS(code) EVP_CipherFinal_ex(self.cipherCtxDec, dest + l1, &l2);

    *destLength = l1 + l2;
    
//    NSLog(@">>> DEC iv: %@", [NSData dataWithBytes:self.cipherIVDec length:self.cipherIVLength]);
//    NSLog(@">>> DEC ad: %@", [NSData dataWithBytes:extra length:self.extraLength]);
//    NSLog(@">>> DEC x: %d", x);
//    NSLog(@">>> DEC tag: %@", [NSData dataWithBytes:bytes length:CryptoAEADTagLength]);
//    NSLog(@">>> DEC dest: %@", [NSData dataWithBytes:dest length:*destLength]);

    TUNNEL_CRYPTO_RETURN_STATUS(code)
}

- (BOOL)verifyBytes:(const uint8_t *)bytes length:(NSInteger)length flags:(const CryptoFlags * _Nullable)flags error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    [NSException raise:NSInvalidArgumentException format:@"Verification not supported"];
    return NO;
}

- (id<DataPathDecrypter>)dataPathDecrypter
{
    return [[DataPathCryptoAEAD alloc] initWithCrypto:self];
}

#pragma mark Helpers

- (void)prepareIV:(uint8_t *)iv withHMACKey:(ZeroingData *)hmacKey
{
    bzero(iv, PacketIdLength);
    memcpy(iv + PacketIdLength, hmacKey.bytes, self.cipherIVLength - PacketIdLength);
}

@end

#pragma mark -

@interface DataPathCryptoAEAD ()

@property (nonatomic, strong) CryptoAEAD *crypto;

@end

@implementation DataPathCryptoAEAD

- (instancetype)initWithCrypto:(CryptoAEAD *)crypto
{
    if ((self = [super init])) {
        self.crypto = crypto;
        self.peerId = PacketPeerIdDisabled;
    }
    return self;
}

#pragma mark DataPathChannel

- (void)setPeerId:(uint32_t)peerId
{
    _peerId = peerId & 0xffffff;
}

- (NSInteger)encryptionCapacityWithLength:(NSInteger)length
{
    return [self.crypto encryptionCapacityWithLength:length];
}

#pragma mark DataPathEncrypter

- (void)assembleDataPacketWithBlock:(DataPathAssembleBlock)block packetId:(uint32_t)packetId payload:(NSData *)payload into:(uint8_t *)packetBytes length:(NSInteger *)packetLength
{
    *packetLength = payload.length;
    if (!block) {
        memcpy(packetBytes, payload.bytes, payload.length);
        return;
    }

    NSInteger packetLengthOffset;
    block(packetBytes, &packetLengthOffset, payload);
    *packetLength += packetLengthOffset;
}

- (NSData *)encryptedDataPacketWithKey:(uint8_t)key packetId:(uint32_t)packetId packetBytes:(const uint8_t *)packetBytes packetLength:(NSInteger)packetLength error:(NSError *__autoreleasing *)error
{
    DATA_PATH_ENCRYPT_INIT(self.peerId)
    
    const int capacity = headerLength + PacketIdLength + (int)[self.crypto encryptionCapacityWithLength:packetLength];
    NSMutableData *encryptedPacket = [[NSMutableData alloc] initWithLength:capacity];
    if (encryptedPacket == NULL) {
        *error = OpenVPNErrorWithCode(OpenVPNErrorCodeCryptoOutOfMemory);
        return nil;
    }
    uint8_t *ptr = encryptedPacket.mutableBytes;
    NSInteger encryptedPacketLength = INT_MAX;

    *(uint32_t *)(ptr + headerLength) = htonl(packetId);

    CryptoFlags flags;
    flags.iv = ptr + headerLength;
    flags.ivLength = PacketIdLength;
    if (hasPeerId) {
        PacketHeaderSetDataV2(ptr, key, self.peerId);
        flags.ad = ptr;
        flags.adLength = headerLength + PacketIdLength;
    }
    else {
        PacketHeaderSet(ptr, PacketCodeDataV1, key, nil);
        flags.ad = ptr + headerLength;
        flags.adLength = PacketIdLength;
    }

    const BOOL success = [self.crypto encryptBytes:packetBytes
                                            length:packetLength
                                              dest:(ptr + headerLength + PacketIdLength) // skip header and packet id
                                        destLength:&encryptedPacketLength
                                             flags:&flags
                                             error:error];
    
    NSAssert(encryptedPacketLength <= capacity, @"Did not allocate enough bytes for payload");
    
    if (!success) {
        return nil;
    }
    
    encryptedPacket.length = headerLength + PacketIdLength + encryptedPacketLength;
    return encryptedPacket;
}

#pragma mark DataPathDecrypter

- (BOOL)decryptDataPacket:(NSData *)packet into:(uint8_t *)packetBytes length:(NSInteger *)packetLength packetId:(uint32_t *)packetId error:(NSError *__autoreleasing *)error
{
    NSAssert(packet.length > 0, @"Decrypting an empty packet, how did it get this far?");

    DATA_PATH_DECRYPT_INIT(packet)
    if (packet.length < headerLength + PacketIdLength) {
        return NO;
    }
    
    CryptoFlags flags;
    flags.iv = packet.bytes + headerLength;
    flags.ivLength = PacketIdLength;
    if (hasPeerId) {
        if (peerId != self.peerId) {
            if (error) {
                *error = OpenVPNErrorWithCode(OpenVPNErrorCodeDataPathPeerIdMismatch);
            }
            return NO;
        }
        flags.ad = packet.bytes;
        flags.adLength = headerLength + PacketIdLength;
    }
    else {
        flags.ad = packet.bytes + headerLength;
        flags.adLength = PacketIdLength;
    }

    // skip header + packet id
    const BOOL success = [self.crypto decryptBytes:(packet.bytes + headerLength + PacketIdLength)
                                            length:(int)(packet.length - (headerLength + PacketIdLength))
                                              dest:packetBytes
                                        destLength:packetLength
                                             flags:&flags
                                             error:error];
    if (!success) {
        return NO;
    }
    *packetId = ntohl(*(const uint32_t *)(flags.iv));
    return YES;
}

- (NSData *)parsePayloadWithBlock:(DataPathParseBlock)block compressionHeader:(nonnull uint8_t *)compressionHeader packetBytes:(nonnull uint8_t *)packetBytes packetLength:(NSInteger)packetLength error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    uint8_t *payload = packetBytes;
    NSUInteger length = packetLength - (int)(payload - packetBytes);
    if (!block) {
        *compressionHeader = 0x00;
        return [NSData dataWithBytes:payload length:length];
    }
    
    NSInteger payloadOffset;
    NSInteger payloadHeaderLength;
    if (!block(payload, &payloadOffset, compressionHeader, &payloadHeaderLength, packetBytes, packetLength, error)) {
        return NULL;
    }
    length -= payloadHeaderLength;
    return [NSData dataWithBytes:(payload + payloadOffset) length:length];
}

@end
