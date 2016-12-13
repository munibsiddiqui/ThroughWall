//
//  ClientConnection.swift
//  ShadowLibTest
//
//  Created by Wu Bin on 11/11/2016.
//  Copyright © 2016 Bin. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack

let ConnectionResponseStr = "HTTP/1.1 200 Connection established\r\n\r\n"
let ConnectionResponse = ConnectionResponseStr.data(using: String.Encoding.utf8)!

let TAG_RECOGNIZE = 0
let TAG_WRITEHTTPSRESPONSR = 1
let TAG_WRITEHTTPRESPONSE = 2
let TAG_WRITETOSERVER = 3
let TAG_WRITETOCLIENT = 4
let TAG_READFROMCLIENT = 12
let TAG_READFROMSERVER = 13
let TAG_HTTPRESPONSE = 14


enum ConnectionError: Error {
    case UnReadableData
    case NoHostInRequest
    case RequestHeaderAnalysisError
    case URLComponentAnalysisError
}

protocol HTTPTrafficTransmitDelegate {
    func HTTPTrafficTransmitDidDisconnect()
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16)
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int)
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int)
}

class HTTPAnalyzer:NSObject, GCDAsyncSocketDelegate, HTTPTrafficTransmitDelegate {
    
    private var outGoing: HTTPTrafficTransmit?
    private var clientSocket: GCDAsyncSocket?
    private var isConnectRequest = true
    private var repostData: Data? = nil
    private var bindToPort = 0
    private var delegate: HTTPAnalyzerDelegate?
    private var intTag = 0
    
    init(analyzerDelegate delegate: HTTPAnalyzerDelegate, intTag tag: Int) {
        self.delegate = delegate
        intTag = tag
    }
    
    func setSocket(_ clientSocket: GCDAsyncSocket, socksServerPort port: Int) {
        clientSocket.delegate = self
        clientSocket.delegateQueue = DispatchQueue.global()
        self.clientSocket = clientSocket
        bindToPort = port
        clientSocket.readData(withTimeout: -1, tag: TAG_RECOGNIZE)
    }
    
    func getIntTag() -> Int {
        return intTag
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if clientSocket == nil {
            DDLogError("H\(intTag) Socks has disconnected")
            return
        }
        if tag == TAG_RECOGNIZE {
            //get destination and port
            analyzeProxy(analyzeData: data, completionHandle: { (host, port) in
                if clientSocket == nil {
                    DDLogError("H\(intTag) Socks has disconnected")
                    return
                }
                outGoing = HTTPTrafficTransmit(withDelegate: self)
                var useProxy = false
                switch Rule.sharedInstance.ruleForDomain(host) {
                case .Proxy:
                    useProxy = true
                    outGoing?.setProxyHost(withHostName: "127.0.0.1", port: UInt16(bindToPort))
                case .Reject:
                    clientSocket?.disconnect()
                default:
                    break
                }
                do {
                    // DDLogVerbose("H\(intTag) Proxy:\(useProxy) Connect: \(host):\(port)")
                    try outGoing?.connnect(toRemoteHost: host, onPort: port)
                }catch{
                    DDLogError("H\(intTag) \(error)")
                }
            }, gotError: { (error) in
                DDLogError("H\(intTag) \(error)")
            })
        }else if tag == TAG_READFROMCLIENT {
//             DDLogVerbose("H\(intTag) From Client length:\(data.count)")
            delegate?.didUploadToServer(dataSize: data.count)
            outGoing?.write(data, withTimeout: -1, tag: TAG_WRITETOSERVER)
//            clientSocket?.readData(withTimeout: -1, tag: TAG_READFROMCLIENT)
        }else if tag == TAG_READFROMSERVER {
//             DDLogVerbose("H\(intTag) From Server length:\(data.count)")
            delegate?.didDownloadFromServer(dataSize: data.count)
            clientSocket?.write(data, withTimeout: -1, tag: TAG_WRITETOCLIENT)
//            DDLogVerbose("H\(intTag) From Server length:\(data.count) End")
//            outGoing?.readData(withTimeout: -1, tag: TAG_READFROMSERVER)
        }else if tag == TAG_HTTPRESPONSE{
            
            clientSocket?.write(data, withTimeout: -1, tag: TAG_WRITEHTTPRESPONSE)
            parseHttpResponse(data)
//            clientSocket?.readData(withTimeout: -1, tag: TAG_READFROMCLIENT)
//            outGoing?.readData(withTimeout: -1, tag: TAG_READFROMSERVER)
            
        }else{
            DDLogError("H\(intTag) Unknow Tag: \(tag)")
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if tag == TAG_WRITETOSERVER {
//            DDLogVerbose("H\(intTag) TAG_WRITETOSERVER")
            clientSocket?.readData(withTimeout: -1, tag: TAG_READFROMCLIENT)
        }else if tag == TAG_WRITETOCLIENT {
//            DDLogVerbose("H\(intTag) TAG_WRITETOCLIENT")
            outGoing?.readData(withTimeout: -1, tag: TAG_READFROMSERVER)
        }else if tag == TAG_WRITEHTTPRESPONSE {
//            DDLogVerbose("H\(intTag) TAG_WRITEHTTPRESPONSE")
            outGoing?.readData(withTimeout: -1, tag: TAG_READFROMSERVER)
        }else if tag == TAG_WRITEHTTPSRESPONSR {
//            DDLogVerbose("H\(intTag) TAG_WRITEHTTPSRESPONSR")
            clientSocket?.readData(withTimeout: -1, tag: TAG_READFROMCLIENT)
            outGoing?.readData(withTimeout: -1, tag: TAG_READFROMSERVER)
        }
    }
    
    func extractDetail(from request: String, by name: String) -> String? {
        var result: String? = nil
        
        guard let nameRange = request.range(of: "\(name): ") else {
            return result
        }
        
        let subRequest = request.substring(with: Range(uncheckedBounds: (lower: nameRange.upperBound, upper: request.endIndex)))
        let returnRange = subRequest.range(of: "\r\n")!
        result = subRequest.substring(with: Range(uncheckedBounds: (lower: subRequest.startIndex, upper: returnRange.lowerBound)))
        
        return result
        
    }
    
    func printData(_ data: Data) {
        let buffer = [UInt8](data)
        var str = "H\(intTag) "
        for i in 0 ..< buffer.count {
            str = str + String.init(format: "%c", buffer[i])
        }
        // DDLogVerbose(str)
        str = "H\(intTag) "
        for i in 0 ..< buffer.count {
            str = str + String.init(format: "%02X ", buffer[i])
        }
        // DDLogVerbose(str)
        
    }
    
    func parseHttpResponse(_ data: Data) {
        guard var serverResponse = String(data: data, encoding: String.Encoding.isoLatin1) else {
            let error = ConnectionError.UnReadableData
            // DDLogVerbose("H\(intTag) \(error)")
            return
        }
        
        let responseComponents = serverResponse.components(separatedBy: "\r\n\r\n")
        serverResponse = responseComponents[0]
        // DDLogVerbose("H\(intTag) " + serverResponse)
        
//        var attatch: Data? = nil
//        
//        if requestComponents.count > 1 {
//            let length = clientRequest.utf8.count + 4
//            attatch = data.subdata(in: length ..< data.count)
//            // DDLogVerbose("reponse data size:\(data.count) reponse attatch size:\(attatch?.count)")
//        }

    }
    
    func findHeaderPart(_ data: Data) -> Int {
        let buffer = [UInt8](data)
        var i = buffer.count - 1
        while i > 3 {
            //0x0a: \n 0x0d: \r
            if buffer[i] == 0x0a && buffer[i - 2] == 0x0a && buffer[i - 1] == 0x0d && buffer[i - 3] == 0x0d {
                return i + 1
            }
            i = i - 1
        }
        return i + 1
    }
    
    func analyzeProxy(analyzeData data: Data, completionHandle: (String, UInt16) -> Void, gotError: (Error) -> Void ) {
        
//        printData(data)
        
        let headerEndIndex = findHeaderPart(data)
        let headerData = data.subdata(in: 0 ..< headerEndIndex)
        
        guard var clientRequest = String(data: headerData, encoding: String.Encoding.utf8) else {
            let error = ConnectionError.UnReadableData
            gotError(error)
            return
        }
        
//        let requestComponents = clientRequest.components(separatedBy: "\r\n\r\n")
//        clientRequest = requestComponents[0]
//         DDLogVerbose("H\(intTag) head \(headerEndIndex) data \(data.count)")
//         DDLogVerbose("H\(intTag) " + clientRequest)
        
//        var attatch: Data? = nil
//        
//        if requestComponents.count > 1 {
//            let length = clientRequest.utf8.count + 4
//            attatch = data.subdata(in: length ..< data.count)
////            // DDLogVerbose("data size:\(data.count) attatch size:\(attatch?.count)")
//        }
        
//        clientRequest = clientRequest + "\r\n"
        guard let hostDomain = extractDetail(from: clientRequest, by: "Host") else {
            gotError(ConnectionError.NoHostInRequest)
            return
        }
        let hostItems = hostDomain.components(separatedBy: ":")
        
        var host = ""
        var port: UInt16 = 0
        if hostItems.count == 2 {
            port = UInt16(hostItems[1]) ?? 80
        }
        
        var request = clientRequest.components(separatedBy: "\r\n")
        var headerComponents = request[0].components(separatedBy: " ")
        
        if headerComponents.count != 3 {
            gotError(ConnectionError.RequestHeaderAnalysisError)
        }
        
        if headerComponents[0] == "CONNECT" {
            isConnectRequest = true
            let urlComponents = headerComponents[1].components(separatedBy: ":")
            host = urlComponents[0]
            let portString = urlComponents[1]
            port = UInt16(portString) ?? 443
        }else{
            isConnectRequest = false
            var urlComponents = headerComponents[1].components(separatedBy: "/")
            if urlComponents.count < 3{
                gotError(ConnectionError.URLComponentAnalysisError)
            }
            
            let hostComponents = urlComponents[2].components(separatedBy: ":")
            if hostComponents[0].contains("[") {
                //ipv6 address
//                host = hostComponents.last!
//                host.remove(at: host.index(before: host.endIndex))
                host = hostItems[0]
            }else{
                host = hostComponents[0]
                if hostComponents.count > 1 {
                    port = UInt16(hostComponents[1]) ?? 80
                }
            }
            
            urlComponents.removeSubrange(0..<3)
            headerComponents[1] = "/\(urlComponents.joined(separator: "/"))"
            request[0] = headerComponents.joined(separator: " ")
            clientRequest = request.joined(separator: "\r\n")
//            if let newRequest = clientRequest.removingPercentEncoding{
//                clientRequest = newRequest
//            }
            // DDLogVerbose("H\(intTag) Repost: \n\(clientRequest)")
            repostData = clientRequest.data(using: .utf8)
            
            if headerEndIndex < data.count {
                repostData?.append(data.subdata(in: headerEndIndex ..< data.count))
            }
            
        }
        if port == 0 {
            port = 80
        }
        
        completionHandle(host,port)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        // DDLogVerbose("H\(intTag) Socks side disconnect")
        
        clientSocket = nil
        if outGoing == nil {
            delegate?.HTTPAnalyzerDidDisconnect(httpAnalyzer: self)
            delegate = nil
        }else{
            outGoing?.disconnect()
        }
    }
    
    func HTTPTrafficTransmitDidDisconnect() {
        // DDLogVerbose("H\(intTag) HTTPTraffic side disconnect")
        
        outGoing = nil
        if clientSocket == nil {
            delegate?.HTTPAnalyzerDidDisconnect(httpAnalyzer: self)
            delegate = nil
        }else{
            clientSocket?.disconnect()
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
//         DDLogVerbose("H\(intTag) didConnect \(host):\(port)")
        
        if isConnectRequest {
//             DDLogVerbose("H\(intTag) Connection")
            clientSocket?.write(ConnectionResponse, withTimeout: -1, tag: TAG_WRITEHTTPSRESPONSR)
//            clientSocket?.readData(withTimeout: -1, tag: TAG_READFROMCLIENT)
//            outGoing?.readData(withTimeout: -1, tag: TAG_READFROMSERVER)
        }else{
//             DDLogVerbose("H\(intTag) None Connection")
            outGoing?.write(repostData!, withTimeout: -1, tag: TAG_WRITETOSERVER)
            repostData = nil
            outGoing?.readData(withTimeout: -1, tag: TAG_HTTPRESPONSE)
//            clientSocket?.readData(withTimeout: -1, tag: TAG_READFROMCLIENT)
        }
    }
}

