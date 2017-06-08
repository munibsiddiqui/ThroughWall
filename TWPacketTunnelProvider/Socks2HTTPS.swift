//
//  Socks2HTTPS.swift
//  ThroughWall
//
//  Created by Bin on 02/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import CocoaAsyncSocket
import CocoaLumberjack


protocol Socks2HTTPSConverterDelegate: class {
    func socketDidDisconnect(_ sock: Socks2HTTPSConverter)
}

// Define various socket tags
private let SOCKS_OPEN = 10100

private let SOCKS_CONNECT_INIT = 10200
private let SOCKS_CONNECT_IPv4 = 10201
private let SOCKS_CONNECT_DOMAIN = 10202
private let SOCKS_CONNECT_DOMAIN_LENGTH = 10212
private let SOCKS_CONNECT_IPv6 = 10203
private let SOCKS_CONNECT_PORT = 10210
private let SOCKS_CONNECT_REPLY = 10300
private let SOCKS_INCOMING_READ = 10400
private let SOCKS_INCOMING_WRITE = 10401
private let SOCKS_OUTGOING_READ = 10500
private let SOCKS_OUTGOING_WRITE = 10501

private let HTTP_PROXY_REQUEST = 10901
private let HTTP_PROXY_REQUEST_RESPONSE = 10902

// Timeouts
private let TIMEOUT_CONNECT = 8.00
private let TIMEOUT_READ = 5.00
private let TIMEOUT_TOTAL = 80.00
private let TIMEOUT_WRITE = 5.00

class Socks2HTTPS: NSObject, GCDAsyncSocketDelegate, Socks2HTTPSConverterDelegate {

    static let sharedInstance = Socks2HTTPS()

    private var socketServer: GCDAsyncSocket!
    private var converts: [Socks2HTTPSConverter]?
    private let lockQueue = DispatchQueue(label: "socks2https.lockQueue")
    private let tagLockQueue = DispatchQueue(label: "socks2https.tagLockQueue")
    private var httpPort: UInt16 = 0
    private var tagCount = 0

    func start(bindToPort toPort: UInt16, callback: (UInt16, Error?) -> Void) {
        socketServer = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
        httpPort = toPort
        converts = [Socks2HTTPSConverter]()
        do {
            try socketServer.accept(onInterface: "127.0.0.1", port: 0)
            callback(socketServer.localPort, nil)
        } catch {
            callback(0, error)
        }
    }

    internal func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        var tag = 0
        tagLockQueue.sync {
            self.tagCount = self.tagCount + 1
            tag = self.tagCount
        }
        
        let newClient = Socks2HTTPSConverter(newSocket, httpPort: httpPort, delegate: self, intTag: tag)
        newSocket.delegate = newClient
        newSocket.delegateQueue = DispatchQueue.global()
        newClient.socksOpen()
        lockQueue.async {
            self.converts?.append(newClient)
            DDLogVerbose("S\(newClient.getIntTag())S added into arrary")
        }
    }

    internal func socketDidDisconnect(_ sock: Socks2HTTPSConverter) {
        lockQueue.async {
            if let index = self.converts?.index(of: sock) {
                self.converts?.remove(at: index)
                DDLogVerbose("S\(sock.getIntTag())S removed from arrary")
            }
        }
    }
}


class Socks2HTTPSConverter: NSObject, GCDAsyncSocketDelegate {
    private var socksConnection: GCDAsyncSocket?
    private var outGoing: GCDAsyncSocket?
    private weak var delegate: Socks2HTTPSConverterDelegate?
    private var httpPort: UInt16!
    private var host: String?
    private var port: UInt16!
    private var responseData: [UInt8]?
    private var intTag = 0

    init(_ socket: GCDAsyncSocket, httpPort: UInt16, delegate: Socks2HTTPSConverterDelegate, intTag tag: Int) {
        socksConnection = socket
        intTag = tag
        self.httpPort = httpPort
        self.delegate = delegate
    }

    func getIntTag() -> Int {
        return intTag
    }

    func socksOpen() {
        socksConnection?.readData(toLength: 3, withTimeout: TIMEOUT_CONNECT, tag: SOCKS_OPEN)
    }

    func socket(_ sock: GCDAsyncSocket, shouldTimeoutReadWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        DDLogVerbose("S\(intTag)S Read Timeout")
        forceDisconnect()
        return 0
    }

    func socket(_ sock: GCDAsyncSocket, shouldTimeoutWriteWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        DDLogVerbose("S\(intTag)S Write Timeout")
        forceDisconnect()
        return 0
    }

    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if tag == SOCKS_OUTGOING_WRITE {
            socksConnection?.readData(withTimeout: -1, tag: SOCKS_INCOMING_READ)
        } else if tag == SOCKS_INCOMING_WRITE {
            outGoing?.readData(withTimeout: -1, tag: SOCKS_OUTGOING_READ)
        }
    }

    internal func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if tag == SOCKS_INCOMING_READ {
            DDLogVerbose("S\(intTag)S SOCKS_INCOMING_READ")
            outGoing?.write(data, withTimeout: -1, tag: SOCKS_OUTGOING_WRITE)
        } else if tag == SOCKS_OUTGOING_READ {
            DDLogVerbose("S\(intTag)S SOCKS_OUTGOING_READ")
            socksConnection?.write(data, withTimeout: TIMEOUT_WRITE, tag: SOCKS_INCOMING_WRITE)
        } else if tag == HTTP_PROXY_REQUEST_RESPONSE {
            DDLogVerbose("S\(intTag)S HTTP_PROXY_REQUEST_RESPONSE")
            let response = String.init(data: data, encoding: String.Encoding.utf8)
            if response != ConnectionResponseStr {
                outGoing?.disconnect()
                socksConnection?.disconnect()
                DDLogError("S\(intTag)S HTTP_PROXY_REQUEST_RESPONSE Error \(response ?? "")")
                return
            }
            var buffer: [UInt8] = [5, 0, 0]
            if let resonse = responseData {
                buffer = buffer + resonse
                responseData = nil
            }
            socksConnection?.write(Data(bytes: buffer), withTimeout: -1, tag: SOCKS_CONNECT_REPLY)
            socksConnection?.readData(withTimeout: -1, tag: SOCKS_INCOMING_READ)
            outGoing?.readData(withTimeout: -1, tag: SOCKS_OUTGOING_READ)
        } else if tag == SOCKS_OPEN {
            let buffer: [UInt8] = [5, 0]

            DDLogVerbose("S\(intTag)S SOCKS_OPEN")
            socksConnection?.write(Data(bytes: buffer), withTimeout: -1, tag: SOCKS_OPEN)
            socksConnection?.readData(toLength: 4, withTimeout: TIMEOUT_READ, tag: SOCKS_CONNECT_INIT)
        } else if tag == SOCKS_CONNECT_INIT {
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
            DDLogVerbose("S\(intTag) SOCKS_CONNECT_INIT")
            let buffer = [UInt8](data)
            let addressType = buffer[3];
            responseData = [addressType]

            if (addressType == 1) {
                socksConnection?.readData(toLength: 4, withTimeout: -1, tag: SOCKS_CONNECT_IPv4)
            } else if (addressType == 3) {
                socksConnection?.readData(toLength: 1, withTimeout: -1, tag: SOCKS_CONNECT_DOMAIN_LENGTH)
            } else if (addressType == 4) {
                socksConnection?.readData(toLength: 16, withTimeout: -1, tag: SOCKS_CONNECT_IPv6)
            }
        } else if tag == SOCKS_CONNECT_IPv4 {
            DDLogVerbose("S\(intTag)S SOCKS_CONNECT_IPv4")
            let buffer = [UInt8](data)
            responseData?.append(contentsOf: buffer)

            let length = Int(INET_ADDRSTRLEN) + 2
            var addressStr = [CChar](repeating: 0, count: length)
            inet_ntop(AF_INET, buffer, &addressStr, socklen_t(length))
            let address = String(cString: &addressStr)
            addressStr.removeAll()
            host = address
            // DDLogVerbose("S\(intTag)S host: \(host)")
            socksConnection?.readData(toLength: 2, withTimeout: -1, tag: SOCKS_CONNECT_PORT)
        } else if tag == SOCKS_CONNECT_IPv6 {
            DDLogVerbose("S\(intTag)S SOCKS_CONNECT_IPv6")
            let buffer = [UInt8](data)
            responseData?.append(contentsOf: buffer)

            let length = Int(INET6_ADDRSTRLEN) + 2
            var addressStr = [CChar](repeating: 0, count: length)
            inet_ntop(AF_INET6, buffer, &addressStr, socklen_t(length))
            let address = String(cString: &addressStr)
            addressStr.removeAll()
            host = address
            DDLogVerbose("S\(intTag)S host6: \(host!)")
            socksConnection?.readData(toLength: 2, withTimeout: -1, tag: SOCKS_CONNECT_PORT)
        } else if tag == SOCKS_CONNECT_DOMAIN_LENGTH {
            DDLogError("S\(intTag)S SOCKS_CONNECT_DOMAIN_LENGTH is strange")
        } else if tag == SOCKS_CONNECT_PORT {
            DDLogVerbose("S\(intTag)S SOCKS_CONNECT_PORT")
            let buffer = [UInt8](data)
            responseData?.append(contentsOf: buffer)
            port = UInt16(buffer[0]) * 256 + UInt16(buffer[1])
            DDLogVerbose("S\(intTag)S port: \(port)")
            do {
                outGoing = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
                try outGoing?.connect(toHost: "127.0.0.1", onPort: httpPort)
            } catch {
                DDLogError("S\(intTag)S Unable to connect local port \(httpPort)")
                outGoing = nil
                socksConnection?.disconnect()
            }
        }
    }

    internal func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        DDLogVerbose("S\(intTag)S HTTPS proxy server connected")
        let request = "CONNECT \(self.host!):\(self.port!) HTTP/1.1\r\nHost: \(self.host!)\r\n\r\n"
        DDLogVerbose("S\(intTag)S \(request)")
        self.host = nil
        outGoing?.write(request.data(using: String.Encoding.utf8)!, withTimeout: -1, tag: HTTP_PROXY_REQUEST)
        outGoing?.readData(withTimeout: TIMEOUT_READ, tag: HTTP_PROXY_REQUEST_RESPONSE)
    }

    internal func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {

        if sock == outGoing {
            DDLogVerbose("S\(intTag)S HTTP side disconnect")
            outGoing = nil
            socksConnection?.disconnect()
        } else if sock == socksConnection {
            DDLogVerbose("S\(intTag)S Socks side disconnect")
            socksConnection = nil
            outGoing?.disconnect()
        } else {
            DDLogVerbose("S\(intTag)S Unknown side disconnect")
            outGoing?.disconnect()
            outGoing = nil
            socksConnection?.disconnect()
            socksConnection = nil
        }
        if outGoing == nil && socksConnection == nil {
            delegate?.socketDidDisconnect(self)
            delegate = nil
        }

        if responseData != nil {
            DDLogVerbose("S\(intTag)S Unbelieveable~~~")
        }
        responseData = nil
    }

    func forceDisconnect() {
        socksConnection?.disconnect()
        DDLogError("S\(intTag)S forceDisconnect")
    }

}
