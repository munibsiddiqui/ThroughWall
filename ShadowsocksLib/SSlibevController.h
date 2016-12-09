//
//  SSlibevController.h
//  ThroughWall
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ShadowsocksClientCompletion)(int port, NSError *error);

@interface SSlibevController : NSObject
- (void) startShodowsocksClientWithhostAddress:(NSString *)host hostPort:(NSNumber *)port hostPassword:(NSString *)password authscheme:(NSString *)method completion:(ShadowsocksClientCompletion)completion;

@end
