//
//  HTTPTrafficTransmit.swift
//  ThroughWall
//
//  Created by Bin on 01/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//


import CocoaAsyncSocket
import CocoaLumberjack


// Define various socket tags
private let SOCKS_OPEN = 10100
private let SOCKS_CONNECT = 10200
private let SOCKS_CONNECT_REPLY_1 = 10300
private let SOCKS_CONNECT_REPLY_2 = 10400
private let SOCKS_AUTH_USERPASS = 10500

// Timeouts
private let TIMEOUT_CONNECT = 8.00
private let TIMEOUT_READ = 5.00
private let TIMEOUT_TOTAL = 80.00

class HTTPTrafficTransmit: NSObject, GCDAsyncSocketDelegate {
    
    private var proxyHost: String?
    private var proxyPort: UInt16?
    private var delegate: HTTPTrafficTransmitDelegate?
    private var shouldConnectDirectly = true
    private var remoteHost: String?
    private var remotePort: UInt16?
    private var socket: GCDAsyncSocket?
    
    func setProxyHost(withHostName host: String, port: UInt16) {
        proxyHost = host
        proxyPort = port
        shouldConnectDirectly = false
    }
    
    init(withDelegate delegate: HTTPTrafficTransmitDelegate) {
        self.delegate = delegate
    }
    
    func connnect(toRemoteHost host: String, onPort port: UInt16) throws {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
        do {
            if shouldConnectDirectly {
                try socket?.connect(toHost: host, onPort: port)
            }else {
                remoteHost = host
                remotePort = port
                try socket?.connect(toHost: proxyHost!, onPort: UInt16(proxyPort!))
            }
        }catch {
            throw error
        }
    }
    
    func disconnect() {
        socket?.disconnect()
//        socket = nil
//        delegate = nil
    }
    
    internal func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if shouldConnectDirectly {
            delegate?.socket(sock, didConnectToHost: host, port: port)
        }else{
            openSocks()
        }
    }
    
    internal  func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        socket = nil
        delegate?.HTTPTrafficTransmitDidDisconnect()
        delegate = nil
    }
    
    internal func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if tag == SOCKS_OPEN {
            let buffer = [UInt8](data)
            
            //      +-----+--------+
            // NAME | VER | METHOD |
            //      +-----+--------+
            // SIZE |  1  |   1    |
            //      +-----+--------+
            //
            // Note: Size is in bytes
            //
            // Version = 5 (for SOCKS5)
            // Method  = 0 (No authentication, anonymous access)
            
            if buffer[0] == 5 && buffer[1] == 0 {
                socksConnect()
            }else{
                socket?.disconnect()
            }
            
        }else if tag == SOCKS_CONNECT_REPLY_1 {
            //    +----+-----+-------+------+----------+----------+
            //    |VER | REP |  RSV  | ATYP | BND.ADDR | BND.PORT |
            //    +----+-----+-------+------+----------+----------+
            //    | 1  |  1  | X'00' |  1   | Variable |    2     |
            //    +----+-----+-------+------+----------+----------+
            //
            //    Where:
            //
            //    o  VER    protocol version: X'05'
            //    o  REP    Reply field:
            //    o  X'00' succeeded
            //    o  X'01' general SOCKS server failure
            //    o  X'02' connection not allowed by ruleset
            //    o  X'03' Network unreachable
            //    o  X'04' Host unreachable
            //    o  X'05' Connection refused
            //    o  X'06' TTL expired
            //    o  X'07' Command not supported
            //    o  X'08' Address type not supported
            //    o  X'09' to X'FF' unassigned
            //    o  RSV    RESERVED
            //    o  ATYP   address type of following address
            let buffer = [UInt8](data)
            
            if buffer[0] != 5 || buffer[1] != 0 {
                socket?.disconnect()
                return
            }
            
            let portLength: UInt = 2
            switch buffer[3] {
            case 1://ipv4
                socket?.readData(toLength: (3 + portLength), withTimeout: TIMEOUT_READ, tag: SOCKS_CONNECT_REPLY_2)
            case 2://domain
                socket?.readData(toLength: (UInt(buffer[4]) + portLength), withTimeout: TIMEOUT_READ, tag: SOCKS_CONNECT_REPLY_2)
            case 6://ipv6
                socket?.readData(toLength: (16 + portLength), withTimeout: TIMEOUT_READ, tag: SOCKS_CONNECT_REPLY_2)
            case 0:
                socket?.readData(toLength: 1, withTimeout: TIMEOUT_READ, tag: SOCKS_CONNECT_REPLY_2)
            default:
                socket?.disconnect()
            }
        }else if tag == SOCKS_CONNECT_REPLY_2 {
            delegate?.socket(sock, didConnectToHost: remoteHost!, port: remotePort!)
        }else{
            delegate?.socket(sock, didRead: data, withTag: tag)
        }
    }
    
    
    private func openSocks() {
        //      +-----+-----------+---------+
        // NAME | VER | NMETHODS  | METHODS |
        //      +-----+-----------+---------+
        // SIZE |  1  |    1      | 1 - 255 |
        //      +-----+-----------+---------+
        //
        // Note: Size is in bytes
        //
        // Version    = 5 (for SOCKS5)
        // NumMethods = 1
        // Method     = 0 (No authentication, anonymous access)
        let buffer: [UInt8] = [5, 1, 0]
        let data = Data(bytes: buffer)
        
        socket?.write(data, withTimeout: -1, tag: SOCKS_OPEN)
        socket?.readData(toLength: 2, withTimeout: TIMEOUT_READ, tag: SOCKS_OPEN)
    }
    
    private func socksConnect() {
        //      +-----+-----+-----+------+------+------+
        // NAME | VER | CMD | RSV | ATYP | ADDR | PORT |
        //      +-----+-----+-----+------+------+------+
        // SIZE |  1  |  1  |  1  |  1   | var  |  2   |
        //      +-----+-----+-----+------+------+------+
        //
        // Note: Size is in bytes
        //
        // Version      = 5 (for SOCKS5)
        // Command      = 1 (for Connect)
        // Reserved     = 0
        // Address Type = 3 (1=IPv4, 3=DomainName 4=IPv6)
        // Address      = P:D (P=LengthOfDomain D=DomainWithoutNullTermination)
        // Port         = 0
        
        var buffer: [UInt8] = [5, 1, 0, 3]
        
        buffer.append(UInt8(remoteHost?.characters.count ?? 0))
        
        let hostArrary = [UInt8]((remoteHost ?? "").utf8)
        buffer = buffer + hostArrary
        buffer.append(UInt8((remotePort ?? 0)/256))
        buffer.append(UInt8((remotePort ?? 0)%256))
        
        let data = Data(bytes: buffer)
        
        socket?.write(data, withTimeout: -1, tag: SOCKS_CONNECT)
        socket?.readData(toLength: 5, withTimeout: TIMEOUT_READ, tag: SOCKS_CONNECT_REPLY_1)
    }
    
    
    func write(_ data: Data, withTimeout timeout: TimeInterval, tag intTag: Int ) {
        socket?.write(data, withTimeout: timeout, tag: intTag)
    }
    
    
    func readData(withTimeout timeout: TimeInterval, tag intTag: Int) {
        socket?.readData(withTimeout: timeout, tag: intTag)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        delegate?.socket(sock, didWriteDataWithTag: tag)
    }
}

