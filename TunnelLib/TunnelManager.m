//
//  TunnelManager.m
//  ThroughWall
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

#import "TunnelManager.h"
#import <netinet/ip.h>
#import <arpa/inet.h>
#import "ipv4/lwip/ip4.h"
#import "lwip/udp.h"
#import "lwip/ip.h"
#import "lwip/inet_chksum.h"
#import "tun2socks/tun2socks.h"

@import CocoaAsyncSocket;
@import CocoaLumberjack;

@interface TunnelManager () <GCDAsyncUdpSocketDelegate>
@property (nonatomic) NEPacketTunnelFlow *tunnelPacketFlow;
@property (nonatomic) NSMutableDictionary *udpSession;
@property (nonatomic) GCDAsyncUdpSocket *udpSocket;
@property (nonatomic) int readFd;
@property (nonatomic) int writeFd;
@end

#define TunnelManagerErrorDomain @"TunnelManager"
static const DDLogLevel ddLogLevel = DDLogLevelDebug;

@implementation TunnelManager

+ (TunnelManager *)sharedInterface {
    static dispatch_once_t onceToken;
    static TunnelManager *interface;
    dispatch_once(&onceToken, ^{
        interface = [TunnelManager new];
    });
    return interface;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _udpSession = [NSMutableDictionary dictionaryWithCapacity:5];
        _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_queue_create("udp", NULL)];
    }
    return self;
}

- (NSError *)startTunnelWithShadowsocksPort:(NSNumber *)shadowsocksPort PacketTunnelFlow:(NEPacketTunnelFlow *)packetFlow {
    if (packetFlow == nil) {
        return [NSError errorWithDomain:Tun2SocksStoppedNotification code:1 userInfo:@{NSLocalizedDescriptionKey: @"PacketTunnelFlow can't be nil."}];
    }
    [TunnelManager sharedInterface].tunnelPacketFlow = packetFlow;
    
    NSError *error;
    GCDAsyncUdpSocket *udpSocket = [TunnelManager sharedInterface].udpSocket;
    [udpSocket bindToPort:0 error:&error];
    if (error) {
        return error;
    }
    [udpSocket beginReceiving:&error];
    if (error) {
        return error;
    }
    
    int fds[2];
    if (pipe(fds) < 0) {
        return [NSError errorWithDomain:TunnelManagerErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Unable to pipe."}];
    }
    [TunnelManager sharedInterface].readFd = fds[0];
    [TunnelManager sharedInterface].writeFd = fds[1];
    
    DDLogDebug(@"Going to start tun2socks");
    //start tun2socks
    [[TunnelManager sharedInterface]startTun2Socks:shadowsocksPort.intValue];
    DDLogDebug(@"tun2socks started");
    //
    [[TunnelManager sharedInterface] processPackets];
    DDLogDebug(@"processpacket");
    return nil;
}

- (void)startTun2Socks: (int)socksServerPort {
    [NSThread detachNewThreadSelector:@selector(_startTun2Socks:) toTarget:[TunnelManager sharedInterface] withObject:@(socksServerPort)];
}

- (void)stop {
    stop_tun2socks();
}

- (void)_startTun2Socks: (NSNumber *)socksServerPort {
    char socks_server[50];
    sprintf(socks_server, "127.0.0.1:%d", (int)([socksServerPort integerValue]));
#if TCP_DATA_LOG_ENABLE
    char *log_lvel = "debug";
#else
    char *log_lvel = "none";
#endif
    char *argv[] = {
        "tun2socks",
        "--netif-ipaddr",
        "192.0.2.4",
        "--netif-netmask",
        "255.255.255.0",
        "--loglevel",
        log_lvel,
        "--socks-server-addr",
        socks_server
    };
    tun2socks_main(sizeof(argv)/sizeof(argv[0]), argv, self.readFd, TunnelMTU);
    close(self.readFd);
    close(self.writeFd);
    [[NSNotificationCenter defaultCenter] postNotificationName:Tun2SocksStoppedNotification object:nil];
}

+ (void)writePacket:(NSData *)packet {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[TunnelManager sharedInterface].tunnelPacketFlow writePackets:@[packet] withProtocols:@[@(AF_INET)]];
    });
}

- (void)processPackets {
    __weak typeof(self) weakSelf = self;
    [[TunnelManager sharedInterface].tunnelPacketFlow readPacketsWithCompletionHandler:^(NSArray<NSData *> * _Nonnull packets, NSArray<NSNumber *> * _Nonnull protocols) {
        for (NSData *packet in packets) {
            uint8_t *data = (uint8_t *)packet.bytes;
            struct ip_hdr *iphdr = (struct ip_hdr *)data;
            uint8_t proto = IPH_PROTO(iphdr);
            if (proto == IP_PROTO_UDP) {
                DDLogVerbose(@"UDP Packet");
                [[TunnelManager sharedInterface] handleUDPPacket:packet];
            }else if (proto == IP_PROTO_TCP) {
                DDLogVerbose(@"TCP Packet");
                [[TunnelManager sharedInterface] handleTCPPPacket:packet];
            }
        }
        [weakSelf processPackets];
    }];
    
}


- (void)handleTCPPPacket: (NSData *)packet {
    uint8_t message[TunnelMTU+2];
    memcpy(message + 2, packet.bytes, packet.length);
    message[0] = packet.length / 256;
    message[1] = packet.length % 256;
    write(self.writeFd , message , packet.length + 2);
}

- (void)handleUDPPacket: (NSData *)packet {
    uint8_t *data = (uint8_t *)packet.bytes;
    int data_len = (int)packet.length;
    struct ip_hdr *iphdr = (struct ip_hdr *)data;
    uint8_t version = IPH_V(iphdr);
    
    switch (version) {
        case 4: {
            uint16_t iphdr_hlen = IPH_HL(iphdr) * 4;
            data = data + iphdr_hlen;
            data_len -= iphdr_hlen;
            struct udp_hdr *udphdr = (struct udp_hdr *)data;
            
            data = data + sizeof(struct udp_hdr *);
            data_len -= sizeof(struct udp_hdr *);
            
            NSData *outData = [[NSData alloc] initWithBytes:data length:data_len];
            struct in_addr dest = { iphdr->dest.addr };
            NSString *destHost = [NSString stringWithUTF8String:inet_ntoa(dest)];
            NSString *key = [self strForHost:iphdr->dest.addr port:udphdr->dest];
            NSString *value = [self strForHost:iphdr->src.addr port:udphdr->src];;
            self.udpSession[key] = value;
            [self.udpSocket sendData:outData toHost:destHost port:ntohs(udphdr->dest) withTimeout:30 tag:0];
            ///////
            //            data = (uint8_t *)packet.bytes;
            //            data_len = (int)packet.length;
            //            NSString * description = [[NSString alloc]init];
            //
            //            for (int i = 0; i < data_len; i++) {
            //                description = [[NSString alloc]initWithFormat:@"%@ %02X" , description, data[i]];
            //            }
            //            DDLogDebug(@"UDP Bytes %@", description);
            //            description = [[NSString alloc]init];
            //            for (int i = 41; i < data_len - 5; i++) {
            //                description = [[NSString alloc]initWithFormat:@"%@ %c" , description, data[i]];
            //            }
            //            DDLogDebug(@"UDP request %@", description);
            //            struct in_addr src = { iphdr->src.addr };
            //            NSString *srcHost = [NSString stringWithUTF8String:inet_ntoa(src)];
            //
            //            DDLogDebug(@"UDP from %@:%hu to %@:%hu", srcHost, ntohs(udphdr->src), destHost, ntohs(udphdr->dest));
            //////
        } break;
        case 6: {
            
        } break;
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    const struct sockaddr_in *addr = (const struct sockaddr_in *)[address bytes];
    ip_addr_p_t dest ={ addr->sin_addr.s_addr };
    in_port_t dest_port = addr->sin_port;
    NSString *strHostPort = self.udpSession[[self strForHost:dest.addr port:dest_port]];
    NSArray *hostPortArray = [strHostPort componentsSeparatedByString:@":"];
    int src_ip = [hostPortArray[0] intValue];
    int src_port = [hostPortArray[1] intValue];
    uint8_t *bytes = (uint8_t *)[data bytes];
    int bytes_len = (int)data.length;
    int udp_length = sizeof(struct udp_hdr) + bytes_len;
    int total_len = IP_HLEN + udp_length;
    
    ip_addr_p_t src = {src_ip};
    struct ip_hdr *iphdr = generateNewIPHeader(IP_PROTO_UDP, dest, src, total_len);
    
    struct udp_hdr udphdr;
    udphdr.src = dest_port;
    udphdr.dest = src_port;
    udphdr.len = hton16(udp_length);
    udphdr.chksum = hton16(0);
    
    uint8_t *udpdata = malloc(sizeof(uint8_t) * udp_length);
    memcpy(udpdata, &udphdr, sizeof(struct udp_hdr));
    memcpy(udpdata + sizeof(struct udp_hdr), bytes, bytes_len);
    
    ip_addr_t odest = { dest.addr };
    ip_addr_t osrc = { src_ip };
    
    struct pbuf *p_udp = pbuf_alloc(PBUF_TRANSPORT, udp_length, PBUF_RAM);
    pbuf_take(p_udp, udpdata, udp_length);
    
    struct udp_hdr *new_udphdr = (struct udp_hdr *) p_udp->payload;
    new_udphdr->chksum = inet_chksum_pseudo(p_udp, IP_PROTO_UDP, p_udp->len, &odest, &osrc);
    
    uint8_t *ipdata = malloc(sizeof(uint8_t) * total_len);
    memcpy(ipdata, iphdr, IP_HLEN);
    memcpy(ipdata + sizeof(struct ip_hdr), p_udp->payload, udp_length);
    
    NSData *outData = [[NSData alloc] initWithBytes:ipdata length:total_len];
    free(ipdata);
    free(iphdr);
    free(udpdata);
    pbuf_free(p_udp);
    [TunnelManager writePacket:outData];
    //    [[TunnelManager sharedInterface]analyUDPOacket:outData];
}

//- (void)analyUDPOacket: (NSData *)packet {
//    uint8_t *data = (uint8_t *)packet.bytes;
//    int data_len = (int)packet.length;
//    struct ip_hdr *iphdr = (struct ip_hdr *)data;
//    uint8_t version = IPH_V(iphdr);
//
//    NSString * description = [[NSString alloc]init];
//
//    for (int i = 0; i < data_len; i++) {
//        description = [[NSString alloc]initWithFormat:@"%@ %02X" , description, data[i]];
//    }
//    DDLogDebug(@"Back UDP Bytes %@", description);
//
//    switch (version) {
//        case 4: {
//            uint16_t iphdr_hlen = IPH_HL(iphdr) * 4;
//            data = data + iphdr_hlen;
//            data_len -= iphdr_hlen;
//            struct udp_hdr *udphdr = (struct udp_hdr *)data;
//
//            data = data + sizeof(struct udp_hdr *);
//            data_len -= sizeof(struct udp_hdr *);
//
////            NSData *outData = [[NSData alloc] initWithBytes:data length:data_len];
//            struct in_addr dest = { iphdr->dest.addr };
//            NSString *destHost = [NSString stringWithUTF8String:inet_ntoa(dest)];
////            NSString *key = [self strForHost:iphdr->dest.addr port:udphdr->dest];
////            NSString *value = [self strForHost:iphdr->src.addr port:udphdr->src];;
////            self.udpSession[key] = value;
////            [self.udpSocket sendData:outData toHost:destHost port:ntohs(udphdr->dest) withTimeout:30 tag:0];
////
//
//            struct in_addr src = { iphdr->src.addr };
//            NSString *srcHost = [NSString stringWithUTF8String:inet_ntoa(src)];
//
//            DDLogDebug(@"Back UDP from %@:%hu to %@:%hu", srcHost, ntohs(udphdr->src), destHost, ntohs(udphdr->dest));
//
//        } break;
//        case 6: {
//
//        } break;
//    }
//}


struct ip_hdr *generateNewIPHeader(uint8_t proto, ip_addr_p_t src, ip_addr_p_t dest, uint16_t total_len) {
    struct ip_hdr *iphdr = malloc(sizeof(struct ip_hdr));
    IPH_VHL_SET(iphdr, 4, IP_HLEN / 4);
    IPH_TOS_SET(iphdr, 0);
    IPH_LEN_SET(iphdr, htons(total_len));
    IPH_ID_SET(iphdr, 0);
    IPH_OFFSET_SET(iphdr, 0);
    IPH_TTL_SET(iphdr, 64);
    IPH_PROTO_SET(iphdr, IP_PROTO_UDP);
    iphdr->src = src;
    iphdr->dest = dest;
    IPH_CHKSUM_SET(iphdr, 0);
    IPH_CHKSUM_SET(iphdr, inet_chksum(iphdr, IP_HLEN));
    return iphdr;
}

- (NSString *)strForHost: (int)host port: (int)port {
    return [NSString stringWithFormat:@"%d:%d",host, port];
}

@end
