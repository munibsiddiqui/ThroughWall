//
//  SSlibevController.m
//  ThroughWall
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

#import "SSlibevController.h"
#import <netinet/in.h>
#import "shadowsocks-libev/src/shadowsocks.h"


@interface SSlibevController()
@property (nonatomic, copy) ShadowsocksClientCompletion shadowCompletion;
@property (nonatomic) int shadowsocksProxyPort;
@property (nonatomic) profile_t profile;
@end

@implementation SSlibevController

void shadowsocks_handler(int fd, void *udata) {
    SSlibevController *provider = (__bridge SSlibevController *)udata;
    [provider onShadowsocksCallback:fd];
}


int sock_port (int fd) {
    struct sockaddr_in sin;
    socklen_t len = sizeof(sin);
    if (getsockname(fd, (struct sockaddr *)&sin, &len) < 0) {
        NSLog(@"getsock_port(%d) error: %s",
              fd, strerror (errno));
        return 0;
    }else{
        return ntohs(sin.sin_port);
    }
}

- (void)onShadowsocksCallback:(int)fd {
    NSError *error;
    if (fd > 0) {
        self.shadowsocksProxyPort = sock_port(fd);
    }else {
        error = [NSError errorWithDomain:@"com.touchingapp.potatso" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Fail to start http proxy"}];
    }
    if (self.shadowCompletion) {
        self.shadowCompletion(self.shadowsocksProxyPort, error);
    }
    
}

- (void) startShodowsocksClientWithhostAddress:(NSString *)host hostPort:(NSNumber *)port hostPassword:(NSString *)password authscheme:(NSString *)method protocol:(NSString *)protocol_ssr obfs:(NSString*)obfs_ssr param:(NSString *)param_ssr completion:(ShadowsocksClientCompletion)completion {
    
    _shadowCompletion = completion;
    
    if (host && port && password && method) {
        profile_t profile;
        memset(&profile, 0, sizeof(profile_t));
        profile.remote_host = strdup([host UTF8String]);
        profile.remote_port = [port intValue];
        profile.password = strdup([password UTF8String]);
        profile.method = strdup([method UTF8String]);
        profile.local_addr = "127.0.0.1";
        profile.local_port = 0;
        profile.timeout = 600;
        profile.auth = false;
        
        if (protocol_ssr &&  ![protocol_ssr  isEqual: @""]) {
            profile.protocol = strdup([protocol_ssr UTF8String]);
        }
        if (obfs_ssr && ![obfs_ssr  isEqual: @""]) {
            profile.obfs = strdup([obfs_ssr UTF8String]);
        }
        if (param_ssr && ![param_ssr  isEqual: @""]) {
            profile.obfs_param = strdup([param_ssr UTF8String]);
        }
        
        _profile = profile;
        
        [NSThread detachNewThreadSelector:@selector(_startShadowsocks) toTarget:self withObject: nil];
        
    }else {
        if (self.shadowCompletion) {
            self.shadowCompletion(0, nil);
        }
        return;
    }
}

- (void)_startShadowsocks {
    start_ss_local_server(_profile, shadowsocks_handler, (__bridge void *)self);
}


@end
