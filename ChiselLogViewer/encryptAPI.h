//
//  encryptAPI.h
//  tunnelTest
//
//  Created by Bin on 6/3/16.
//  Copyright © 2016 Bin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "encrypt.h"

@interface encryptAPI : NSObject

- (void) initEncryption: (struct encryption_ctx *)ctx;
- (void) configEncryptionWithPawwsord:(const char *)password  method:(const char *)method;

- (void) encryptBufWithCTX:(struct encryption_ctx*)ctx buffer:(unsigned char *)buf length:(size_t *)len;

- (void) decryptBufWithCTX:(struct encryption_ctx*)ctx buffer:(unsigned char *)buf length:(size_t *)len;

@end
