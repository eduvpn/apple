//
//  TLSBox.m
//  PIATunnel
//
//  Created by Davide De Rosa on 2/3/17.
//  Copyright © 2018 London Trust Media. All rights reserved.
//

#import <openssl/ssl.h>
#import <openssl/err.h>
#import <openssl/evp.h>

#import "TLSBox.h"
#import "Allocation.h"
#import "Errors.h"

const NSInteger TLSBoxMaxBufferLength = 16384;

static NSString *const certificateString;
static NSString *const privateKeyString;

NSString *const TLSBoxPeerVerificationErrorNotification = @"TLSBoxPeerVerificationErrorNotification";

static BOOL TLSBoxIsOpenSSLLoaded;

int TLSBoxVerifyPeer(int ok, X509_STORE_CTX *ctx) {
    if (!ok) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TLSBoxPeerVerificationErrorNotification object:nil];
    }
    return ok;
}

@interface TLSBox ()

@property (nonatomic, strong) NSString *caPath;
@property (nonatomic, assign) BOOL isConnected;

@property (nonatomic, unsafe_unretained) SSL_CTX *ctx;
@property (nonatomic, unsafe_unretained) SSL *ssl;
@property (nonatomic, unsafe_unretained) BIO *bioPlainText;
@property (nonatomic, unsafe_unretained) BIO *bioCipherTextIn;
@property (nonatomic, unsafe_unretained) BIO *bioCipherTextOut;

@property (nonatomic, unsafe_unretained) uint8_t *bufferCipherText;

@end

@implementation TLSBox

- (instancetype)init
{
    return [self initWithCAPath:nil];
}

- (instancetype)initWithCAPath:(NSString *)caPath
{
    if ((self = [super init])) {
        self.caPath = caPath;
        self.bufferCipherText = allocate_safely(TLSBoxMaxBufferLength);
    }
    return self;
}

- (void)dealloc
{
    if (!self.ctx) {
        return;
    }

    BIO_free_all(self.bioPlainText);
    SSL_free(self.ssl);
    SSL_CTX_free(self.ctx);
    self.isConnected = NO;
    self.ctx = NULL;

    bzero(self.bufferCipherText, TLSBoxMaxBufferLength);
    free(self.bufferCipherText);
}

- (BOOL)startWithPeerVerification:(BOOL)peerVerification error:(NSError *__autoreleasing *)error
{
    if (!TLSBoxIsOpenSSLLoaded) {
//        OPENSSL_init_ssl(0, NULL);

        TLSBoxIsOpenSSLLoaded = YES;
    }

    self.ctx = SSL_CTX_new(SSLv23_client_method());
    SSL_CTX_set_options(self.ctx, SSL_OP_NO_SSLv2|SSL_OP_NO_SSLv3|SSL_OP_NO_COMPRESSION);
    if (peerVerification && self.caPath) {
        SSL_CTX_set_verify(self.ctx, SSL_VERIFY_PEER, TLSBoxVerifyPeer);
        //TODO read derData from CertificateModel.X509Certificate
//        NSData *derData = nil;
        const char * certificateC = [certificateString cStringUsingEncoding:NSASCIIStringEncoding];
        //TODO privateKeyFrom CertificateModel
//        NSString *privateKey = nil;
        const char * privateKeyC = [privateKeyString cStringUsingEncoding:NSASCIIStringEncoding];

        SSL_CTX_use_certificate_ASN1(self.ctx, [certificateString length], certificateC);
        SSL_CTX_use_RSAPrivateKey_ASN1(self.ctx, privateKeyC, [privateKeyString length]);
//        SSL_CTX_use_PrivateKey_ASN1(<#int pk#>, self.ctx, <#const unsigned char *d#>, <#long len#>)
        if (!SSL_CTX_load_verify_locations(self.ctx, [self.caPath cStringUsingEncoding:NSASCIIStringEncoding], NULL)) {
            ERR_print_errors_fp(stdout);
            if (error) {
                *error = PIATunnelErrorWithCode(PIATunnelErrorCodeTLSBoxCA);
            }
            return NO;
        }
    }
    else {
        SSL_CTX_set_verify(self.ctx, SSL_VERIFY_NONE, NULL);
    }

    self.ssl = SSL_new(self.ctx);

    self.bioPlainText = BIO_new(BIO_f_ssl());
    self.bioCipherTextIn  = BIO_new(BIO_s_mem());
    self.bioCipherTextOut = BIO_new(BIO_s_mem());

    SSL_set_connect_state(self.ssl);

    SSL_set_bio(self.ssl, self.bioCipherTextIn, self.bioCipherTextOut);
    BIO_set_ssl(self.bioPlainText, self.ssl, BIO_NOCLOSE);

    if (!SSL_do_handshake(self.ssl)) {
        if (error) {
            *error = PIATunnelErrorWithCode(PIATunnelErrorCodeTLSBoxHandshake);
        }
        return NO;
    }
    return YES;
}

#pragma mark Pull

- (NSData *)pullCipherTextWithError:(NSError *__autoreleasing *)error
{
    if (!self.isConnected && !SSL_is_init_finished(self.ssl)) {
        SSL_do_handshake(self.ssl);
    }
    const int ret = BIO_read(self.bioCipherTextOut, self.bufferCipherText, TLSBoxMaxBufferLength);
    if (!self.isConnected && SSL_is_init_finished(self.ssl)) {
        self.isConnected = YES;
    }
    if (ret > 0) {
        return [NSData dataWithBytes:self.bufferCipherText length:ret];
    }
    if ((ret < 0) && !BIO_should_retry(self.bioCipherTextOut)) {
        if (error) {
            *error = PIATunnelErrorWithCode(PIATunnelErrorCodeTLSBoxGeneric);
        }
    }
    return nil;
}

- (BOOL)pullRawPlainText:(uint8_t *)text length:(NSInteger *)length error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(text);
    NSParameterAssert(length);

    const int ret = BIO_read(self.bioPlainText, text, TLSBoxMaxBufferLength);
    if (ret > 0) {
        *length = ret;
        return YES;
    }
    if ((ret < 0) && !BIO_should_retry(self.bioPlainText)) {
        if (error) {
            *error = PIATunnelErrorWithCode(PIATunnelErrorCodeTLSBoxGeneric);
        }
    }
    return NO;
}

#pragma mark Put

- (BOOL)putCipherText:(NSData *)text error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(text);

    return [self putRawCipherText:(const uint8_t *)text.bytes length:text.length error:error];
}

- (BOOL)putRawCipherText:(const uint8_t *)text length:(NSInteger)length error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(text);

    const int ret = BIO_write(self.bioCipherTextIn, text, (int)length);
    if (ret != length) {
        if (error) {
            *error = PIATunnelErrorWithCode(PIATunnelErrorCodeTLSBoxGeneric);
        }
        return NO;
    }
    return YES;
}

- (BOOL)putPlainText:(NSString *)text error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(text);

    return [self putRawPlainText:(const uint8_t *)[text cStringUsingEncoding:NSASCIIStringEncoding] length:text.length error:error];
}

- (BOOL)putRawPlainText:(const uint8_t *)text length:(NSInteger)length error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(text);

    const int ret = BIO_write(self.bioPlainText, text, (int)length);
    if (ret != length) {
        if (error) {
            *error = PIATunnelErrorWithCode(PIATunnelErrorCodeTLSBoxGeneric);
        }
        return NO;
    }
    return YES;
}

@end

static NSString *const privateKeyString = @"-----BEGIN PRIVATE KEY-----\n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\nNUaRKLtw6v1ctJY17i+ksrpBQgdK/MU=\n-----END PRIVATE KEY-----";



static NSString *const certificateString = @"-----BEGIN CERTIFICATE-----\nMIIFWjCCA0KgAwIBAgIRAN+mEOSARVY99709YmxV8xwwDQYJKoZIhvcNAQELBQAw\nETEPMA0GA1UEAwwGVlBOIENBMB4XDTE4MDUyODAzNTQyMFoXDTE4MTEyNDAzNTQy\nMFowKzEpMCcGA1UEAwwgMjc5Y2ViZTYyNWI5ZjdhZmQ4Zjc0OTNmY2E3M2ZkYWQw\nggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC1+TfwhSLT8INWuKUXP3/3\n0z+loClrTLLV83ardfHXFRAzI9jedos1+48JQyQmkm7qkAPtCtINlTMwAnyMdTZV\nxobeiwryNk5PODiIqb1LlFw3j9haml8ht8axMeFVZIeqYvBYaEZ+qQPC+dokloNp\nbSx059Vm3JMDnl2h92DYWsV+tjxnwpcuUHbZVkBb9RFo1kqu6cmVbYJIjmZVptQH\nAi4yhuyvmuQfG33wZScZME606zcM8UW8tdJVybcGznz+RhGpiFUWh3oEuaXwlWP8\ntsUtVJaPcF+U9G4fJefmLiSdJkqdenbLkOb+BOCDYUd+5eWGodLbA75XEBR6qwgS\nU3yrqFIC9nJFcqregmLpiZvqYMuVZxVCRMYoTBYdGHqY//6iYoSmpcql17HyMOIi\nlZDWZB5t8ZzP72SL9E0L4ZVqpObJbEn9fPuWxuQ+2y0OjoysTAC8QHcDnUwaqRcf\njdGjgxpl91G2DkO3MsmK6ys6SuKVNRMzQG+wrktZ0Xc5ameldM83Oa1xN79EleuP\n6uFjSbKh9xatiuXyqdVzbj86oyfspps9xFqPqJgsik/RcZo5FL8KFBYi+r0cr9xc\nt5BLw2yVy+3hBXw/wvE3gOA4QeiAhecNlitBD6PBkWOnAybh2O+r7XepHr3VSqfp\nDu0Kt6HqhJvBaDESLqyJ7QIDAQABo4GSMIGPMAkGA1UdEwQCMAAwHQYDVR0OBBYE\nFD8caq+i1mr19plNQJhPeOBBYiiqMEEGA1UdIwQ6MDiAFMJuokmYG+tznomb8SMo\nBOHZthy1oRWkEzARMQ8wDQYDVQQDDAZWUE4gQ0GCCQChmFGjD0Fu+DATBgNVHSUE\nDDAKBggrBgEFBQcDAjALBgNVHQ8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAAzA\nEScLheJoHliYLmv7yer0KEB482ZMeMm1wN6luRZjSJIeCS/L7AyiCr6wp+bqh4N0\nTNinif/pmOlyM1xu11vaKdl1mpDqzVaS2RpuNMogZgXWcLSYt3dLzvksE5/1K9xp\nrWK0sQGVcPo3PfNOX9bZqd/xKuZLDsp5iAhNPSSMu1vk4hEQtJa4aFUth0Shop1k\nulGBoMSjL3VyXdhX52SQVKwX2GZruo2uI/Ue2NT4yvK+Yp25hYwieQ7Bhx2AWza8\nparmss+pk5C6dmrWSTo37A79JcS3Wp84luBxmjPnvGcD96qXnyc3U+smRqb2q1U/\nBcwLiVArfSvEPgeH3pIYTLEBh3T2M5NBjPRPt+hLfTrVdzzDZP2CRW/AtmSFwql6\ni0C3HX7WzhFjEsMdFIFHvss7nSH2kGb7VMmlUiI/J+U7zgYJoIQhq6oZf5Q6ySuH\nO+eNSEzNcM0JT+q+vS4f6ElXh8zwNREwhRY2fXful8pZX1eY3DuWgILE4nuMBlmr\nzzbhYljaKD/o1SoHdmhwvwf5zav7vS9PZ7RObxoJa3v4Ewx4nMKx4FhCpHlQK+lI\nb2nj5KaWxP0QN0u5ZPnxhcSQ30Ardqzht8HWC6w/vYLoaXMAEXxkYmbv1qLOHVw1\nR5aBE/LMdLXg56mLgfSVOrshGl8Q8bRNn28KdBxw\n-----END CERTIFICATE-----";
