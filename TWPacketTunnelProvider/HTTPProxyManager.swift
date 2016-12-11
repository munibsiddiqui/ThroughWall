//
//  ProxyManager.swift
//  ThroughWall
//
//  Created by Wu Bin on 13/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack

protocol HTTPAnalyzerDelegate {
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer)
    func didDownloadFromServer(dataSize size: Int)
    func didUploadToServer(dataSize size: Int)
}

class HTTPProxyManager: NSObject, GCDAsyncSocketDelegate,HTTPAnalyzerDelegate {
    
    static let shardInstance = HTTPProxyManager()
    
    private var bindToPort = 0
    private var socketServer: GCDAsyncSocket!
    private var clientSocket = [HTTPAnalyzer]()
    private let analyzerLock = NSLock()
    private let downloadLock = NSLock()
    private let uploadLock = NSLock()
    private let tagLock = NSLock()
    private var downloadCount = 0
    private var uploadCount = 0
    private var timer: DispatchSourceTimer?
    private var tagCount = 0
    
    func startProxy(bindToPort toPort: Int, callback: (Int, Error?) -> Void) {
        let localPort = 0
        bindToPort = toPort

        socketServer = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
        do {
            try socketServer.accept(onInterface: "127.0.0.1", port: UInt16(localPort))
        }catch{
            callback(0, error)
            return
        }
        prepareTimelyUpdate()
        callback(Int(socketServer.localPort), nil)
    }
    
    func stopProxy() {
        timer?.cancel()
        timer = nil
    }
    
    func prepareTimelyUpdate() {
        timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "updateQueue") )
        timer?.scheduleRepeating(deadline: .now() + .seconds(1), interval: .seconds(1), leeway: .milliseconds(100))
        timer?.setEventHandler(handler: {
            let (download, upload) = self.readDownloadUploadCount()
//            DDLogVerbose("download:\(download) upload:\(upload)")
            let defaults = UserDefaults.init(suiteName: groupName)
            
            defaults?.set(download, forKey: downloadCountKey)
            defaults?.set(upload, forKey: uploadCountKey)
            defaults?.synchronize()
            
            let notification = CFNotificationCenterGetDarwinNotifyCenter()
            
            let name = DarwinNotifications.updateWidget.rawValue
            
            CFNotificationCenterPostNotification(notification, CFNotificationName(name as CFString) , nil, nil, true)
            
        })
        timer?.resume()
    }
    
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer) {
        analyzerLock.lock()
            if let index = self.clientSocket.index(of: analyzer) {
                self.clientSocket.remove(at: index)
                DDLogVerbose("H\(analyzer.getIntTag()) removed from arrary")
            }
        analyzerLock.unlock()
    }
    
    func didDownloadFromServer(dataSize size: Int) {
        downloadLock.lock()
            self.downloadCount = self.downloadCount + size
        downloadLock.unlock()
    }
    
    func didUploadToServer(dataSize size: Int) {
        uploadLock.lock()
            self.uploadCount = self.uploadCount + size
        uploadLock.unlock()
    }
    
    func readDownloadUploadCount() -> (Int, Int) {
        var download = 0
        var upload = 0
        downloadLock.lock()
            download = self.downloadCount
            self.downloadCount = 0
        downloadLock.unlock()
        uploadLock.lock()
        upload = self.uploadCount
            self.uploadCount = 0
        uploadLock.unlock()
        return (download, upload)
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        var tag = 0
        tagLock.lock()
            self.tagCount = self.tagCount + 1
            tag = self.tagCount
        tagLock.unlock()
        
        let newClient = HTTPAnalyzer(analyzerDelegate: self, intTag: tag)
        newClient.setSocket(newSocket, socksServerPort: bindToPort)
        analyzerLock.lock()
        self.clientSocket.append(newClient)
        DDLogVerbose("H\(newClient.getIntTag()) added into arrary")
        analyzerLock.unlock()
    }
    
}
