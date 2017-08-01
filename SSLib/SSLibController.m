//
//  SSLibController.m
//  SSLib
//
//  Created by Bin on 31/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

#import "SSLibController.h"
#import <netinet/in.h>
#import "shadowsocks-libev/src/shadowsocks.h"

@interface SSLibController()
@property (nonatomic, copy) SSClientCompletion shadowCompletion;
@property (nonatomic) int shadowsocksProxyPort;
@property (nonatomic) profile_t profile;
@end

@implementation SSLibController

void shadowsocks_handler(int fd, void *udata) {
    SSLibController *provider = (__bridge SSLibController *)udata;
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

- (void) startSSClientWithhostAddress:(NSString *)host hostPort:(NSNumber *)port hostPassword:(NSString *)password authscheme:(NSString *)method completion:(SSClientCompletion)completion {
    
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
