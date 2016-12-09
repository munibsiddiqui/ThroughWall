//
//  TunnelManager.h
//  ThroughWall
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

#import <Foundation/Foundation.h>

@import NetworkExtension;

#define TunnelMTU 1600
#define Tun2SocksStoppedNotification @"Tun2SocksStopped"


@interface TunnelManager : NSObject

+ (TunnelManager *)sharedInterface;
- (NSError *)startTunnelWithShadowsocksPort:(NSNumber *)shadowsocksPort PacketTunnelFlow:(NEPacketTunnelFlow *)packetFlow;
+ (void)writePacket: (NSData *)packet;
+ (void)stop;

@end
