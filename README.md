# ThroughWall

Proxy on iOS using Network Extension feature.
Some ideas are from open source project [Potatso](https://github.com/shadowsocks/Potatso).

Before building, use pod install to setup.

To run this app in a real device, Network Extension Permission should be authorized from Apple. For more info, please Google.


## Currently Supported Proxies
- shadowsocks (Global/Auto  Mode)


## Used Open-source Libraries
- CocoaAsyncSocket
- CocoaLumberjack
- tun2socks-iOS
- shadowsocks-libev


## TBD
- Rewrite tun2socks-iOS & shadowsocks-libev

-------------
I know tun2socks-iOS and shadowsocks-libev, but was not clear about how to put them together. Thanks to [Potatso](https://github.com/shadowsocks/Potatso), I finally make it out.
