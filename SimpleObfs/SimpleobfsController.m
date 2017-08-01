//
//  SimpleobfsController.m
//  Simple-obfs
//
//  Created by Bin on 01/08/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

#import "SimpleobfsController.h"
#import "simple-obfs/src/simple-obfs.h"

@interface SimpleobfsController()
@property (nonatomic, copy) SimpleobfsCompletion obfsCompletion;
@property (nonatomic) int obfsLocalPort;
@property (nonatomic) profile_t profile;
@end

@implementation SimpleobfsController

void simpleObfs_handler( void *udata) {
    SimpleobfsController *provider = (__bridge SimpleobfsController *)udata;
    [provider onObfsCallback];
}

- (void)onObfsCallback {
    if (self.obfsCompletion) {
        self.obfsCompletion(self.obfsLocalPort, nil);
    }
    
}
- (void) startSimpleobfsWithHostAddr:(NSString *)hostAddr hostPort:(NSNumber *)port pluginOpts:(NSString *)options completion:(SimpleobfsCompletion)completion {
    _obfsLocalPort = get_local_port();
    _obfsCompletion = completion;
    
    profile_t profile;
    memset(&profile, 0, sizeof(profile_t));
    profile.ss_remote_host = strdup([hostAddr UTF8String]);
    profile.ss_remote_port = strdup([[[NSString alloc]initWithFormat:@"%@", port] UTF8String]);
    profile.ss_local_host = "127.0.0.1";
    profile.ss_local_port = strdup([[[NSString alloc]initWithFormat:@"%d", _obfsLocalPort] UTF8String]);
    profile.ss_plugin_opts = strdup([options UTF8String]);
    
    _profile = profile;

    [NSThread detachNewThreadSelector:@selector(_startSimpleobfs) toTarget:self withObject: nil];
    
}

- (void)_startSimpleobfs {
    simple_obfs_start(_profile, simpleObfs_handler, (__bridge void *)self);
}

@end
