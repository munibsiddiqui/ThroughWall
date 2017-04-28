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
let crlfData = Data.init(bytes: [0x0d, 0x0a, 0x0d, 0x0a])

let TAG_READ_REQUEST_HEAD_FROM_CLIENT = 10
let TAG_READ_REQUEST_BODY_FROM_CLIENT = 12
let TAG_READ_FROM_CLIENT = 13

let TAG_READ_RESPONSE_FROM_SERVER = 20
let TAG_READ_FROM_SERVER = 23

let TAG_WRITE_HTTPS_RESPONSE = 30
let TAG_WRITE_RESPONSE_TO_CLIENT = 31
let TAG_WRITE_TO_CLIENT = 32

let TAG_WRITE_TO_SERVER = 40
let TAG_WRITE_REQUEST_TO_SERVER = 41


let ST_READ_RESPONSE_HEAD_FROM_SERVER = 1
let ST_READ_LEFT_RESPONSE_HEAD_FROM_SERVER = 2
let ST_READ_RESPONSE_BODY_FROM_SERVER = 3

enum ConnectionError: Error {
    case UnReadableData
    case NoHostInRequest
    case RequestHeaderAnalysisError
    case URLComponentAnalysisError
    case IPV6AnalysisError
    case HostNilError
    case StateError
}

protocol OutgoingTransmitDelegate: class {
    func outgoingSocketDidDisconnect(_ outgoing: OutgoingSide)
    func outgoingSocket(didConnectToHost host: String, port: UInt16)
    func outgoingSocket(didRead data: Data, withTag tag: Int)
    func outgoingSocket(didWriteDataWithTag tag: Int)
}

class HTTPAnalyzer:NSObject, GCDAsyncSocketDelegate, OutgoingTransmitDelegate {
    private var clientSocket: GCDAsyncSocket?
    private var bindToPort = 0
    private weak var delegate: HTTPAnalyzerDelegate?
    private var intTag = 0
    private var dataLengthFromClient = 0
    private var outGoing: OutgoingSide?
    private var repostData: Data? = nil
    private var proxyType = ""
    private var hostAndPort = ""
    private var isConnectRequest = true
    private var shouldParseTraffic = false
    private var isForceDisconnect = false
    private var shouldKeepAlive = false
    private var brokenData: Data?
    private var responseFromServerstate: Int?
    private lazy var hostTraffic: HostTraffic = {
        let context = CoreDataController.sharedInstance.getContext()
        let hostTraffic = HostTraffic(context: context)
        hostTraffic.inProcessing = true
        return hostTraffic
    }()
    
    private var inCount = 0 {
        willSet{
            DispatchQueue.main.async {
                self.hostTraffic.inCount = Int64(newValue)
            }
        }
    }
    private var outCount = 0 {
        willSet {
            DispatchQueue.main.async {
                self.hostTraffic.outCount = Int64(newValue)
            }
        }
    }
    
    // MARK: - init part
    
    init(analyzerDelegate delegate: HTTPAnalyzerDelegate, intTag tag: Int) {
        super.init()
        readStoredKey()
        self.delegate = delegate
        intTag = tag
    }
    
    func setSocket(clientSocket socket: GCDAsyncSocket, socksServerPort port: Int) {
        socket.delegate = self
        socket.delegateQueue = DispatchQueue.global()
        clientSocket = socket
        bindToPort = port

        clientSocket?.readData(to: crlfData, withTimeout: TimeInterval(10), tag: TAG_READ_REQUEST_HEAD_FROM_CLIENT)
    }
    
    
    func readStoredKey() {
        let defaults = UserDefaults.init(suiteName: groupName)
        if let keyValue = defaults?.value(forKey: shouldParseTrafficKey) as? Bool {
            shouldParseTraffic = keyValue
        }
        
    }
    
    func getIntTag() -> Int {
        return intTag
    }
    
    // MARK: - GCDAsyncSocketDelegate
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if tag == TAG_WRITE_TO_CLIENT {
            DDLogVerbose("H\(intTag)H TAG_WRITE_TO_CLIENT")
            outGoing?.readData(withTimeout: -1, tag: TAG_READ_FROM_SERVER)
        }else if tag == TAG_WRITE_HTTPS_RESPONSE {
            DDLogVerbose("H\(intTag)H TAG_WRITE_HTTPS_RESPONSE")
            clientSocket?.readData(withTimeout: -1, tag: TAG_READ_FROM_CLIENT)
            outGoing?.readData(withTimeout: -1, tag: TAG_READ_FROM_SERVER)
        }else if tag == TAG_WRITE_RESPONSE_TO_CLIENT {
            DDLogVerbose("H\(intTag)H TAG_WRITE_RESPONSE_TO_CLIENT")
            outGoing?.readData(withTimeout: -1, tag: TAG_READ_RESPONSE_FROM_SERVER)
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if clientSocket == nil{
            DDLogError("H\(intTag)H Socks has disconnected")
            return
        }
        switch tag {
        case TAG_READ_REQUEST_HEAD_FROM_CLIENT:
            DDLogVerbose("H\(intTag)H TAG_READ_REQUEST_HEAD_FROM_CLIENT length:\(data.count)")
            didReadClientRequestHead(withData: data)
        case TAG_READ_REQUEST_BODY_FROM_CLIENT:
            DDLogVerbose("H\(intTag)H TAG_READ_REQUEST_BODY_FROM_CLIENT length:\(data.count)")
            didReadClientRequestBody(withData: data)
        case TAG_READ_FROM_CLIENT:
            DDLogVerbose("H\(intTag)H TAG_READ_FROM_CLIENT length:\(data.count)")
            dataLengthFromClient = data.count
            outGoing?.write(data, withTimeout: -1, tag: TAG_WRITE_TO_SERVER)
        default:
            break
        }
    }
    
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogVerbose("H\(intTag)H Socks side disconnect")
        
        clientSocket = nil
        if outGoing == nil {
            DDLogVerbose("H\(intTag)H Both side disconnected")
            saveInOutCount()
            delegate?.HTTPAnalyzerDidDisconnect(httpAnalyzer: self)
            delegate = nil
        }else{
            if shouldKeepAlive && !isForceDisconnect{
                DDLogVerbose("H\(intTag)H Going to save Outgoing instance")
                delegate?.saveOutgoingSideIntoKeepAliveArray(withHostNameAndPort: hostAndPort, outgoing: outGoing!)
                outGoing = nil
                saveInOutCount()
                delegate?.HTTPAnalyzerDidDisconnect(httpAnalyzer: self)
                delegate = nil
            }else{
                DDLogVerbose("H\(intTag)H Going to disconnect Outgoing Side")
                outGoing?.disconnect()
            }
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, shouldTimeoutReadWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        DispatchQueue.global().async {
            self.forceDisconnect()
        }
        return 0
    }
    
    // MARK: - Process Data from client
    
    func didReadClientRequestHead(withData data: Data) {

        guard let clientRequestString = String(data: data, encoding: String.Encoding.utf8) else {
            let error = ConnectionError.UnReadableData
            DDLogError("H\(intTag)H didReadClientRequest: \(error)")
            return
        }
        
        DDLogVerbose("H\(intTag)H head \(data.count)")
        DDLogVerbose("H\(intTag)H " + clientRequestString)
        
        if isCONNECTRequest(clientRequestString) {
            isConnectRequest = true
            handleHTTPSRequest(withRequest: clientRequestString)
        }else{
            isConnectRequest = false
            handleHTTPRequestHead(withRequest: clientRequestString)
        }
    }
    
    func didReadClientRequestBody(withData data: Data) {
        recordBody(withData: data, type: "request")
        outGoing?.write(data, withTimeout: -1, tag: TAG_WRITE_REQUEST_TO_SERVER)
    }
    
    func isCONNECTRequest(_ request: String) -> Bool {
        if request.hasPrefix("CONNECT") {
            return  true
        }
        return false
    }
    
    func handleHTTPSRequest(withRequest request: String) {
        var (host, port) = getHostAndPort(fromHostComponentOfRequest: request)
        if host == nil || port == nil {
            var requestComponents = request.components(separatedBy: "\r\n")
            
            let (hostName, portNumber) = extractHostAndPort(fromCONNECTComponent: requestComponents[0])
            
            if host == nil {
                host = hostName
            }
            if port == nil {
                port = portNumber ?? 443
            }
            
            if host != nil {
                if shouldParseTraffic {
                    DispatchQueue.main.async {
                        self.hostTraffic.requestHead = request
                    }
                }
                tryConnect(toHost: host!, port: port!)
            }else{
                DDLogError("H\(intTag)H handleHTTPSRequest \(ConnectionError.HostNilError)")
                forceDisconnect()
                return
            }
        }else{
            tryConnect(toHost: host!, port: port!)
        }
    }
    
    func handleHTTPRequestHead(withRequest request: String) {
        var (host, port) = getHostAndPort(fromHostComponentOfRequest: request)
        let (hostName, replaced, portNumber, repostRequest) = extractHostAndPortWithRepost(fromRequest: request)
        
        if host == nil || replaced {
            host = hostName
        }
        
        if port == nil {
            port = portNumber ?? 80
        }
        
        if host != nil && repostRequest !=  nil {
            if shouldParseTraffic {
                DispatchQueue.main.async {
                    self.hostTraffic.requestHead = repostRequest
                    CoreDataController.sharedInstance.saveContext()
                }
            }
            DDLogVerbose("H\(intTag)H repost \(repostRequest!)")
            repostData = repostRequest?.data(using: String.Encoding.utf8)
            tryConnect(toHost: host!, port: port!)
        }else{
            DDLogError("H\(intTag)H handleHTTPSRequest \(ConnectionError.HostNilError)")
            forceDisconnect()
            return
        }
    }
    
    func getHostAndPort(fromHostComponentOfRequest request: String) -> (String?, UInt16?) {
        let hostDomain = extractDetail(from: request, by: "Host")
        let hostItems = hostDomain?.components(separatedBy: ":")
        
        var host: String?
        var port: UInt16?
        if hostItems != nil {
            host = hostItems![0]
            if hostItems!.count == 2 {
                port = UInt16(hostItems![1])
            }
        }
        return (host, port)
    }
    
    func getKeepAliveInfo(fromRequest request: String) -> Bool {
        if let connetionType = extractDetail(from: request, by: "Connection") {
            if connetionType.lowercased() != "keep-alive" {
                return false
            }
        }
//        return true
        return false
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
    
    func extractHostAndPort(fromCONNECTComponent component: String) -> (String?, UInt16?) {
        let destiReqComponents = component.components(separatedBy: " ")
        if destiReqComponents.count != 3 {
            DDLogError("H\(intTag)H extactHostAndPort: \(ConnectionError.RequestHeaderAnalysisError)")
            return (nil, nil)
        }
        
        if destiReqComponents[1].hasPrefix("[") {
            //ipv6 address
            let destiComponents = destiReqComponents[1].components(separatedBy: "]")
            if destiComponents.count == 2 {
                var host = destiComponents[0]
                host.remove(at: host.startIndex)
                var port = destiComponents[1]
                if port.hasPrefix(":") {
                    port.remove(at: port.startIndex)
                }
                return (host, UInt16(port))
            }else{
                DDLogError("H\(intTag)H extactHostAndPort: \(ConnectionError.IPV6AnalysisError)")
                return (nil , nil)
            }
        }else{
            //ipv4 address or domain
            let destiComponents = destiReqComponents[1].components(separatedBy: ":")
            if destiComponents.count == 2{
                let host = destiComponents[0]
                let port = destiComponents[1]
                return (host,UInt16(port))
            }else{
                return (destiComponents[0], nil)
            }
        }
    }
    
    func extractHostAndPortWithRepost(fromRequest request: String) -> (String?, Bool, UInt16?, String?) {
        var requestComponents = request.components(separatedBy: "\r\n")
        var destiReqComponents = requestComponents[0].components(separatedBy: " ")
        var host = ""
        var port: UInt16?
        if destiReqComponents.count != 3 {
            DDLogError("H\(intTag)H extractHostAndPortWithRepost: \(ConnectionError.RequestHeaderAnalysisError)")
            return (nil, false, nil, nil)
        }
        
        //destiReqComponents[1]: http://***/...
        let newDestiReqComponent = Rule.sharedInstance.tryRewriteURL(withURLString: destiReqComponents[1])
        let replaced: Bool
        if newDestiReqComponent == destiReqComponents[1] {
            replaced = false
        }else{
            replaced = true
        }
        var destiComponents = newDestiReqComponent.components(separatedBy: "/")
        if destiComponents.count < 3{
            DDLogError("H\(intTag)H extractHostAndPortWithRepost: \(ConnectionError.URLComponentAnalysisError)")
            return (nil, replaced, nil, nil)
        }
        
        if destiComponents[2].hasPrefix("[") {
            //ipv6 address
            let hostAndPortComponents = destiComponents[2].components(separatedBy: "]")
            if hostAndPortComponents.count == 2{
                host = hostAndPortComponents[0]
                host.remove(at: host.startIndex)
                var _port = hostAndPortComponents[1]
                if _port.hasPrefix(":") {
                    _port.remove(at: _port.startIndex)
                }
                port = UInt16(_port)
            }else{
                DDLogError("H\(intTag)H extractHostAndPortWithRepost: \(ConnectionError.IPV6AnalysisError)")
                return (nil , replaced, nil, nil)
            }
        }else{
            //ipv4 address or domain
            let hostAndPortComponents = destiComponents[2].components(separatedBy: ":")
            if hostAndPortComponents.count == 2{
                host = hostAndPortComponents[0]
                port = UInt16(hostAndPortComponents[1])
            }else{
                host = hostAndPortComponents[0]
            }
        }
        
        destiComponents.removeSubrange(0..<3)
        destiReqComponents[1] = "/\(destiComponents.joined(separator: "/"))"
        requestComponents[0] = destiReqComponents.joined(separator: " ")
        let repostRequest = requestComponents.joined(separator: "\r\n")
        return (host, replaced, port, repostRequest)
    }
    
    
    func tryConnect(toHost host: String, port: UInt16) {
        let rule = Rule.sharedInstance.ruleForDomain(host)
        proxyType = rule.description
        DDLogVerbose("H\(intTag)H Proxy:\(proxyType) Connect: \(host):\(port)")
        if shouldParseTraffic {
            DispatchQueue.main.async {
                self.hostTraffic.hostName = host
                self.hostTraffic.port = Int32(port)
                self.hostTraffic.rule = self.proxyType
                self.hostTraffic.requestTime = NSDate()
            }
        }
        
        outGoing = reuseOutGoingInstance(usingHost: host, port: port)
        if outGoing == nil {
            outGoing = OutgoingSide(withDelegate: self)
        }else{
            outgoingSocket(didConnectToHost: host, port: port)
            return
        }
        
        switch rule {
        case .Reject:
            outGoing = nil
            forceDisconnect()
            return
        case .Proxy:
            outGoing?.setProxyHost(withHostName: "127.0.0.1", port: UInt16(bindToPort))
        default:
            break
        }
        
        do {
            try outGoing?.connnect(toRemoteHost: host, onPort: port)
        }catch{
            DDLogError("H\(intTag)H \(error)")
            outGoing = nil
            forceDisconnect()
        }
    }
    
    
    func reuseOutGoingInstance(usingHost host: String, port: UInt16) -> OutgoingSide? {
        hostAndPort = "\(host):\(port)"
        if let _outgoing = delegate?.retrieveOutGoingInstance(byHostNameAndPort: hostAndPort) {
            _outgoing.setDelegate(self)
            return _outgoing
        }
        return nil
    }
    
    
    
    //---------------------------------
    // MARK: - OutGoingTransmitDelegate
    //---------------------------------
    internal func outgoingSocket(didWriteDataWithTag tag: Int) {
        if shouldParseTraffic {
            outCount = outCount + dataLengthFromClient
        }
        delegate?.didUploadToServer(dataSize: dataLengthFromClient, proxyType: proxyType)
        
        if tag == TAG_WRITE_TO_SERVER {
            DDLogVerbose("H\(intTag)H TAG_WRITE_TO_SERVER")
            clientSocket?.readData(withTimeout: -1, tag: TAG_READ_FROM_CLIENT)
        }else if tag == TAG_WRITE_REQUEST_TO_SERVER {
            DDLogVerbose("H\(intTag)H TAG_WRITE_REQUEST_TO_SERVER")
            clientSocket?.readData(withTimeout: -1, tag: TAG_READ_REQUEST_BODY_FROM_CLIENT)
        }else{
            DDLogError("H\(intTag)H Unknown Outgoing didwrite Tag \(tag)")
        }
    }
    
    internal func outgoingSocket(didRead data: Data, withTag tag: Int) {
        if shouldParseTraffic {
            inCount = inCount + data.count
        }
        delegate?.didDownloadFromServer(dataSize: data.count, proxyType: proxyType)
        
        switch tag {
        case TAG_READ_FROM_SERVER:
            DDLogVerbose("H\(intTag)H TAG_READ_FROM_SERVER length:\(data.count)")
            clientSocket?.write(data, withTimeout: -1, tag: TAG_WRITE_TO_CLIENT)
        case TAG_READ_RESPONSE_FROM_SERVER:
            DDLogVerbose("H\(intTag)H TAG_READ_RESPONSE_FROM_SERVER length:\(data.count)")
            didReadServerResponse(withData: data)
        default:
            DDLogError("H\(intTag)H Unknown Outgoing didread Tag")
            break
        }
    }
    
    internal func outgoingSocket(didConnectToHost host: String, port: UInt16) {
        DDLogVerbose("H\(intTag)H didConnect \(host):\(port)")
        
        if isConnectRequest {
            if shouldParseTraffic {
                DispatchQueue.main.async {
                    self.hostTraffic.responseHead = ConnectionResponseStr
                    self.hostTraffic.responseTime = NSDate()
                }
            }
            clientSocket?.write(ConnectionResponse, withTimeout: -1, tag: TAG_WRITE_HTTPS_RESPONSE)
        }else{
            outGoing?.write(repostData!, withTimeout: -1, tag: TAG_WRITE_REQUEST_TO_SERVER)
            dataLengthFromClient = repostData!.count
            repostData = nil
            responseFromServerstate = ST_READ_RESPONSE_HEAD_FROM_SERVER
            
            outGoing?.readData(withTimeout: -1, tag: TAG_READ_RESPONSE_FROM_SERVER)
        }
    }
    
    func retrievedOutgoingSocket(host: String, port: UInt16) {
        DDLogVerbose("H\(intTag)H retrievedOutgoingSocket \(host):\(port)")
        
        if isConnectRequest {
            if shouldParseTraffic {
                DispatchQueue.main.async {
                    self.hostTraffic.responseHead = ConnectionResponseStr
                    self.hostTraffic.responseTime = NSDate()
                }
            }
            clientSocket?.write(ConnectionResponse, withTimeout: -1, tag: TAG_WRITE_HTTPS_RESPONSE)
        }else{
            outGoing?.write(repostData!, withTimeout: -1, tag: TAG_WRITE_REQUEST_TO_SERVER)
            dataLengthFromClient = repostData!.count
            repostData = nil
            responseFromServerstate = ST_READ_RESPONSE_HEAD_FROM_SERVER
            //alread read at last period.
        }
    }
    
    internal func outgoingSocketDidDisconnect(_ outgoing: OutgoingSide) {
        DDLogVerbose("H\(intTag)H Outgoing side disconnect")
        outGoing = nil
        if clientSocket == nil {
            DDLogVerbose("H\(intTag)H Both side disconnected")
            saveInOutCount()
            delegate?.HTTPAnalyzerDidDisconnect(httpAnalyzer: self)
            delegate = nil
        }else{
            DDLogVerbose("H\(intTag)H Going to disconnect Socks Side")
            clientSocket?.disconnect()
        }
    }
    
    // MARK: - Other
    
    func forceDisconnect() {
        isForceDisconnect = true
        clientSocket?.disconnect()
        DDLogVerbose("H\(intTag)H forceDisconnect")
    }
    
    func saveInOutCount() {
        if shouldParseTraffic {
            DispatchQueue.main.sync {
                if self.hostTraffic.requestTime == nil {
                    DDLogVerbose("H\(self.intTag)H DELETE from context")
                    CoreDataController.sharedInstance.getContext().delete(self.hostTraffic)
                }else{
                    DDLogVerbose("H\(self.intTag)H saveInOutCount")
                    self.hostTraffic.inCount = Int64(self.inCount)
                    self.hostTraffic.outCount = Int64(self.outCount)
                    self.hostTraffic.inProcessing = false
                    self.hostTraffic.disconnectTime = NSDate()
                    self.hostTraffic.forceDisconnect = self.isForceDisconnect
                    CoreDataController.sharedInstance.saveContext()
                    CoreDataController.sharedInstance.getContext().refresh(self.hostTraffic, mergeChanges: false)
                }
            }
        }
    }
    
    private func printData(_ data: Data) {
        let buffer = [UInt8](data)
        var str = "H\(intTag)H "
        for i in 0 ..< buffer.count {
            str = str + String.init(format: "%c", buffer[i])
        }
        DDLogVerbose(str)
        str = "H\(intTag)H "
        for i in 0 ..< buffer.count {
            str = str + String.init(format: "%02X ", buffer[i])
        }
        DDLogVerbose(str)
        
    }
    
    func didReadServerResponse(withData data: Data) {
        guard let state = responseFromServerstate  else{
            return
        }
        
        switch state {
        case ST_READ_RESPONSE_HEAD_FROM_SERVER:
            DDLogVerbose("H\(intTag)H ST_READ_RESPONSE_HEAD_FROM_SERVER")
            didReadServerResponseHead(withData: data)
        case ST_READ_LEFT_RESPONSE_HEAD_FROM_SERVER:
            DDLogVerbose("H\(intTag)H ST_READ_LEFT_RESPONSE_HEAD_FROM_SERVER")
            didReadLeftServerResponse(withData: data)
        case ST_READ_RESPONSE_BODY_FROM_SERVER:
            DDLogVerbose("H\(intTag)H ST_READ_RESPONSE_BODY_FROM_SERVER")
            didReadLeftResponseBody(withData: data)
        default:
            DDLogError("H\(intTag)H \(ConnectionError.StateError)")
            break
        }
    
    }
    
    func findHeadEndIndex(_ data: Data) -> Int? {
        let buffer = [UInt8](data)
        var i = 0
        
        while i < buffer.count - 3 {
            if buffer[i] == 0x0d && buffer[i + 2] == 0x0d && buffer[i + 1] == 0x0a && buffer[i + 3] == 0x0a {
                return i + 4
            }
            i = i + 1
        }
        return nil
    }
    
    func didReadServerResponseHead(withData data: Data) {
        var headData = data
        var bodyData: Data?
        guard let headEndIndex = findHeadEndIndex(data) else{
            brokenData = data
            responseFromServerstate = ST_READ_LEFT_RESPONSE_HEAD_FROM_SERVER
            outGoing?.readData(withTimeout: -1, tag: TAG_READ_RESPONSE_FROM_SERVER)
            return
        }
        
        if headEndIndex < data.count {
            headData = data.subdata(in: 0 ..< headEndIndex)
            bodyData = data.subdata(in: headEndIndex ..< data.count)
        }
        
        guard let serverResponseString = String(data: headData, encoding: String.Encoding.utf8) else {
            let error = ConnectionError.UnReadableData
            DDLogError("H\(intTag)H parseHttpResponse: \(error)")
            return
        }
        
        if shouldParseTraffic {
            DispatchQueue.main.async {
                self.hostTraffic.responseHead = serverResponseString
                self.hostTraffic.responseTime = NSDate()
            }
        }
        
        shouldKeepAlive = getKeepAliveInfo(fromRequest: serverResponseString)
        
        DDLogVerbose("H\(intTag)H KeepAlive: \(shouldKeepAlive)")
        DDLogVerbose("H\(intTag)H " + serverResponseString)

        if let _bodyData = bodyData {
            recordBody(withData: _bodyData, type: "respnose")
        }
        responseFromServerstate = ST_READ_RESPONSE_BODY_FROM_SERVER
        clientSocket?.write(data, withTimeout: -1, tag: TAG_WRITE_RESPONSE_TO_CLIENT)
    }
    
    func didReadLeftServerResponse(withData data: Data) {
        let maybeCompleteData = brokenData! + data
        //
        // what if there's a bug, and the data keeps growing ?????
        //
        didReadServerResponseHead(withData: maybeCompleteData)
    }
    
    func didReadLeftResponseBody(withData data: Data) {
        recordBody(withData: data, type: "respnose")
        clientSocket?.write(data, withTimeout: -1, tag: TAG_WRITE_RESPONSE_TO_CLIENT)
    }
    
    func recordBody(withData data: Data, type: String) {
        if shouldParseTraffic {
            DispatchQueue.main.async {
                DDLogVerbose("H\(self.intTag)H Record: \(data.count)")
                let context = CoreDataController.sharedInstance.getContext()
                let pieceBody = PieceData(context: context)
                pieceBody.timeStamp = NSDate()
                pieceBody.type = type
                pieceBody.rawData = data as NSData?
                pieceBody.belongToTraffic = self.hostTraffic
                self.hostTraffic.addToBodies(pieceBody)
                
                CoreDataController.sharedInstance.saveContext()
                CoreDataController.sharedInstance.getContext().refresh(pieceBody, mergeChanges: false)
                
            }
        }
    }
}

