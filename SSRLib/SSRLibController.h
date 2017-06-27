//
//  SSRLibController.h
//  ThroughWall
//
//  Created by Bingo on 26/06/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ShadowsocksClientCompletion)(int port, NSError *error);

@interface SSRLibController : NSObject
- (void) startShodowsocksClientWithhostAddress:(NSString *)host hostPort:(NSNumber *)port hostPassword:(NSString *)password authscheme:(NSString *)method protocol:(NSString *)protocol_ssr pro_para:(NSString *)p_para obfs:(NSString*)obfs_ssr obfs_para:(NSString *)o_para completion:(ShadowsocksClientCompletion)completion;

@end
