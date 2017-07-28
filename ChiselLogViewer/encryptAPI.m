//
//  encryptAPI.m
//  tunnelTest
//
//  Created by Bin on 6/3/16.
//  Copyright © 2016 Bin. All rights reserved.
//

#import "encryptAPI.h"

@implementation encryptAPI


- (void) initEncryption:(struct encryption_ctx *)ctx {
    init_encryption(ctx);
}

- (void) configEncryptionWithPawwsord:(const char *)password method:(const char *)method {
    config_encryption(password, method);
}


- (void)encryptBufWithCTX:(struct encryption_ctx *)ctx buffer:(unsigned char *)buf length:(size_t *)len {
    encrypt_buf(ctx, buf, len);
}

- (void)decryptBufWithCTX:(struct encryption_ctx *)ctx buffer:(unsigned char *)buf length:(size_t *)len {
    decrypt_buf(ctx, buf, len);
}

@end
