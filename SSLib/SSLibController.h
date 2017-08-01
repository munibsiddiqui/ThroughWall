//
//  SSLibController.h
//  SSLib
//
//  Created by Bin on 31/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SSClientCompletion)(int port, NSError *error);

@interface SSLibController : NSObject

- (void) startSSClientWithhostAddress:(NSString *)host hostPort:(NSNumber *)port hostPassword:(NSString *)password authscheme:(NSString *)method completion:(SSClientCompletion)completion;

@end
