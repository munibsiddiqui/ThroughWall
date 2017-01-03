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
import CoreData

let ConnectionResponseStr = "HTTP/1.1 200 Connection established\r\n\r\n"
let ConnectionResponse = ConnectionResponseStr.data(using: String.Encoding.utf8)!

let TAG_READ_REQUEST_CLIENT = 10


enum ConnectionError: Error {
    case UnReadableData
    case NoHostInRequest
    case RequestHeaderAnalysisError
    case URLComponentAnalysisError
}

protocol HTTPTrafficTransmitDelegate: class {
    func HTTPTrafficTransmitDidDisconnect()
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16)
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int)
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int)
}

class HTTPAnalyzer:NSObject, GCDAsyncSocketDelegate, HTTPTrafficTransmitDelegate {
    
    private var clientSocket: GCDAsyncSocket?
    private var bindToPort = 0
    private weak var delegate: HTTPAnalyzerDelegate?
    private var intTag = 0
    private var shouldLogTraffic = false
    
    internal func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        <#code#>
    }

    internal func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        <#code#>
    }

    internal func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        <#code#>
    }

    internal func HTTPTrafficTransmitDidDisconnect() {
        <#code#>
    }

    init(analyzerDelegate delegate: HTTPAnalyzerDelegate, intTag tag: Int, clientSocket socket: GCDAsyncSocket, socksServerPort port: Int) {
        self.delegate = delegate
        intTag = tag
        
        socket.delegate = self
        socket.delegateQueue = DispatchQueue.global()
        clientSocket = socket
        bindToPort = port
        
        clientSocket?.readData(withTimeout: -1, tag: TAG_READ_REQUEST_CLIENT)
    }
    
    func readStoredKey() {
        let defaults = UserDefaults.init(suiteName: groupName)
        if let keyValue = defaults?.value(forKey: shouldLogTrafficKey) as? Bool {
            shouldLogTraffic = keyValue
        }
        
    }
    
    
    
    
    
}

