//
//  SimpleobfsController.h
//  Simple-obfs
//
//  Created by Bin on 01/08/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SimpleobfsCompletion)(int port, NSError *error);

@interface SimpleobfsController : NSObject

- (void) startSimpleobfsWithHostAddr:(NSString *)hostAddr hostPort:(NSNumber *)port pluginOpts:(NSString *)options completion:(SimpleobfsCompletion)completion;

@end
