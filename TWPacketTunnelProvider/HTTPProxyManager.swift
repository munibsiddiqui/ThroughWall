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
import CoreData

protocol HTTPAnalyzerDelegate: class {
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer)
    func didDownloadFromServer(dataSize size: Int, proxyType proxy: String)
    func didUploadToServer(dataSize size: Int, proxyType proxy: String)
    func retrieveOutGoingInstance(byHostNameAndPort hostAndPort:String) -> OutgoingSide?
    func saveOutgoingSideIntoKeepAliveArray(withHostNameAndPort hostAndPort: String, outgoing: OutgoingSide)
}

class HTTPProxyManager: NSObject, GCDAsyncSocketDelegate, HTTPAnalyzerDelegate, OutgoingTransmitDelegate {
    
    static let shardInstance = HTTPProxyManager()
    
    private var bindToPort = 0
    private var socketServer: GCDAsyncSocket!
    private var clientSocket = [HTTPAnalyzer]()
    private let analyzerLock = NSLock()
    private let downloadLock = NSLock()
    private let uploadLock = NSLock()
    private let tagLock = NSLock()
    private let outgoingStoreLock = NSLock()
    private var downloadCount = 0
    private var proxyDownloadCount = 0
    private var directDownloadCount = 0
    private var uploadCount = 0
    private var proxyUploadCount = 0
    private var directUploadCount = 0
    private var saveTrafficTimer: DispatchSourceTimer?
    private var repeatDeleteTimer: DispatchSourceTimer?
    private var repeatDisconnectTimer: DispatchSourceTimer?
    private var tagCount = 0
    private var outgoingStorage = [String:[OutgoingSide]]()
    struct downUpTraffic {
        var proxyDownload = 0
        var directDownload = 0
        var proxyUpload  = 0
        var directUpload = 0
    }
    
    
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
        socketServer.disconnect()

        for client in clientSocket {
            client.forceDisconnect()
        }
        
        while true {
            if clientSocket.count  == 0 {
                break
            }
        }
        
        saveTrafficTimer?.cancel()
        saveTrafficTimer = nil
        repeatDeleteTimer?.cancel()
        repeatDeleteTimer = nil
        repeatDisconnectTimer?.cancel()
        repeatDisconnectTimer = nil
        DDLogVerbose("Going to saveContext")
        DispatchQueue.main.sync {
            CoreDataController.sharedInstance.saveContext()
            CoreDataController.sharedInstance.getContext().reset()
        }
    }
    
    func prepareTimelyUpdate() {
        repeatlySaveTraffic(withInterval: 1)
        repeatlyDeleteOldHistory(before: 12 * 3600, withRepeatPeriod: 100)
        repeatlyDisconnectOutgoing(withMaxKeepAliveTime: 6 * 60, checkPeriod: 60)
    }
    
    func repeatlySaveTraffic(withInterval interval: Int)  {
        saveTrafficTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "saveQueue") )
        saveTrafficTimer?.scheduleRepeating(deadline: .now() + .seconds(interval), interval: .seconds(interval), leeway: .milliseconds(100))
        saveTrafficTimer?.setEventHandler(handler: {
            let (download, proxyDownload, directDownload, upload, proxyUpload, directUpload) = self.readDownloadUploadCount()
            // DDLogVerbose("download:\(download) upload:\(upload)")
            let defaults = UserDefaults.init(suiteName: groupName)
            
            defaults?.set(download, forKey: downloadCountKey)
            defaults?.set(upload, forKey: uploadCountKey)
            
            let localFormatter = DateFormatter()
            localFormatter.locale = Locale.current
            localFormatter.dateFormat = "yyyy-MM"
            let currentDate = localFormatter.string(from: Date())
            if let recordingDate = defaults?.value(forKey: recordingDateKey) as? String {
                if currentDate == recordingDate {
                    let pDownload = defaults?.value(forKey: proxyDownloadCountKey) as? Int ?? 0
                    let pUpload  = defaults?.value(forKey: proxyUploadCountKey) as? Int ?? 0
                    defaults?.set(pDownload + proxyDownload, forKey: proxyDownloadCountKey)
                    defaults?.set(pUpload + proxyUpload, forKey: proxyUploadCountKey)
                }else{
                    let oldProxyDownload = defaults?.value(forKey: proxyDownloadCountKey) as! Int
                    let oldProxyUpload = defaults?.value(forKey: proxyUploadCountKey) as! Int
                    let oldDate = localFormatter.date(from: recordingDate)
                    self.archiveOldMonthHistory(oldProxyDownload, oldProxyUpload: oldProxyUpload, oldDate: oldDate! as NSDate)
                    defaults?.set(proxyDownload, forKey: proxyDownloadCountKey)
                    defaults?.set(proxyUpload, forKey: proxyUploadCountKey)
                    defaults?.set(currentDate, forKey: recordingDateKey)
                }
            }else{
                defaults?.set(proxyDownload, forKey: proxyDownloadCountKey)
                defaults?.set(proxyUpload, forKey: proxyUploadCountKey)
                defaults?.set(currentDate, forKey: recordingDateKey)
            }
            
            defaults?.synchronize()
            
            let traffic = downUpTraffic(proxyDownload: proxyDownload, directDownload: directDownload, proxyUpload: proxyUpload, directUpload: directUpload)
            
            self.saveTraffic(traffic)
            
            let notification = CFNotificationCenterGetDarwinNotifyCenter()
            
            let name = DarwinNotifications.updateWidget.rawValue
            
            CFNotificationCenterPostNotification(notification, CFNotificationName(name as CFString) , nil, nil, true)
            
        })
        saveTrafficTimer?.resume()
    }
    
    func archiveOldMonthHistory(_ oldProxyDownload: Int, oldProxyUpload: Int, oldDate: NSDate) {
        DispatchQueue.main.async {
            let context = CoreDataController.sharedInstance.getContext()
            let proxyHisTraffic = HistoryTraffic(context: context)
            proxyHisTraffic.hisType = "month"
            proxyHisTraffic.inCount = Int64(oldProxyDownload)
            proxyHisTraffic.outCount = Int64(oldProxyUpload)
            proxyHisTraffic.proxyType = "Proxy"
            proxyHisTraffic.timestamp = oldDate
            proxyHisTraffic.pathType = "WIFI"
            
            CoreDataController.sharedInstance.saveContext()
        }
    }
    
    func repeatlyDeleteOldHistory(before beforeSeconds: Int, withRepeatPeriod repeatPeriod: Int){
        repeatDeleteTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "deleteQueue") )
        repeatDeleteTimer?.scheduleRepeating(deadline: .now() + .seconds(repeatPeriod), interval: .seconds(repeatPeriod), leeway: .milliseconds(100))
        repeatDeleteTimer?.setEventHandler(handler: { 
            DispatchQueue.main.async {
                let oldTime = NSDate.init(timeInterval: TimeInterval(-1 * beforeSeconds), since: Date())
                
                let fetchOldData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
                fetchOldData.predicate = NSPredicate(format: "timestamp < %@ && hisType == %@", oldTime, "second")
                
                do {
                    let oldData = try CoreDataController.sharedInstance.getContext().fetch(fetchOldData)
                    for data in oldData {
                        CoreDataController.sharedInstance.getContext().delete(data)
                    }
                    CoreDataController.sharedInstance.saveContext()
                }catch{
                    print(error)
                }
            }
        })
        repeatDeleteTimer?.resume()
    }
    
    func saveTraffic(_ traffic : downUpTraffic) {
        DispatchQueue.main.async {
            let context = CoreDataController.sharedInstance.getContext()
            
            let timestamp = NSDate()
            
            if traffic.proxyDownload > 0 || traffic.proxyUpload > 0 {
                let proxyHisTraffic = HistoryTraffic(context: context)
                proxyHisTraffic.hisType = "second"
                proxyHisTraffic.inCount = Int64(traffic.proxyDownload)
                proxyHisTraffic.outCount = Int64(traffic.proxyUpload)
                proxyHisTraffic.proxyType = "Proxy"
                proxyHisTraffic.timestamp = timestamp
                proxyHisTraffic.pathType = "WIFI"
                
                CoreDataController.sharedInstance.saveContext()
                CoreDataController.sharedInstance.getContext().refresh(proxyHisTraffic, mergeChanges: false)
            }
            
            if traffic.directDownload > 0 || traffic.directUpload > 0 {
                let directHisTraffic = HistoryTraffic(context: context)
                directHisTraffic.hisType = "second"
                directHisTraffic.inCount = Int64(traffic.directDownload)
                directHisTraffic.outCount = Int64(traffic.directUpload)
                directHisTraffic.proxyType = "Direct"
                directHisTraffic.timestamp = timestamp
                directHisTraffic.pathType = "WIFI"
                
                CoreDataController.sharedInstance.saveContext()
                CoreDataController.sharedInstance.getContext().refresh(directHisTraffic, mergeChanges: false)
            }

        }
    }
    
    func repeatlyDisconnectOutgoing(withMaxKeepAliveTime maxAliveTime: Int, checkPeriod: Int) {
        repeatDisconnectTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "disconnectQueue") )
        repeatDisconnectTimer?.scheduleRepeating(deadline: .now() + .seconds(checkPeriod), interval: .seconds(checkPeriod), leeway: .milliseconds(100))
        
        repeatDisconnectTimer?.setEventHandler(handler: {
            let currentDate = Date()
            
            self.outgoingStoreLock.lock()
            let siteOutgoings = self.outgoingStorage.values
            
            for outgoings in siteOutgoings {
                for outgoing in outgoings {
                    if let storeDate = outgoing.getStoreTime() {
                        if Int(storeDate.timeIntervalSince(currentDate)) > maxAliveTime {
                            //disconnect
                            DDLogVerbose("KAK Timeout \(outgoing.getHostAndPort())")
                            outgoing.disconnect()
                        }
                    }
                }
            }
            
            for key in self.outgoingStorage.keys {
                print("KAK \(key): \(self.outgoingStorage[key]?.count ?? 0)")
            }
            
            self.outgoingStoreLock.unlock()
        })
        
        repeatDisconnectTimer?.resume()
    }
    
    
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer) {
        analyzerLock.lock()
        if let index = self.clientSocket.index(of: analyzer) {
            self.clientSocket.remove(at: index)
            DDLogVerbose("H\(analyzer.getIntTag())H removed from arrary")
        }else{
            DDLogError("H\(analyzer.getIntTag())H cann't find in the array")
        }
        analyzerLock.unlock()
    }
    
    func didDownloadFromServer(dataSize size: Int, proxyType proxy: String) {
        downloadLock.lock()
        self.downloadCount = self.downloadCount + size
        switch proxy {
        case "Proxy":
            self.proxyDownloadCount = self.proxyDownloadCount + size
        case "Direct":
            self.directDownloadCount = self.directDownloadCount + size
        default:
            break
        }
        downloadLock.unlock()
    }
    
    func didUploadToServer(dataSize size: Int, proxyType proxy: String) {
        uploadLock.lock()
        self.uploadCount = self.uploadCount + size
        switch proxy {
        case "Proxy":
            self.proxyUploadCount = self.proxyUploadCount + size
        case "Direct":
            self.directUploadCount = self.directUploadCount + size
        default:
            break
        }
        uploadLock.unlock()
    }
    
    func readDownloadUploadCount() -> (Int, Int, Int, Int, Int, Int) {
        var download = 0
        var proxyDownload = 0
        var directDownload = 0
        var upload = 0
        var proxyUpload  = 0
        var directUpload = 0
        downloadLock.lock()
        download = self.downloadCount
        proxyDownload =  self.proxyDownloadCount
        directDownload = self.directDownloadCount
        self.downloadCount = 0
        self.proxyDownloadCount = 0
        self.directDownloadCount = 0
        downloadLock.unlock()
        uploadLock.lock()
        upload = self.uploadCount
        proxyUpload = self.proxyUploadCount
        directUpload = self.directUploadCount
        self.uploadCount = 0
        self.proxyUploadCount = 0
        self.directUploadCount = 0
        uploadLock.unlock()
        return (download, proxyDownload, directDownload, upload, proxyUpload, directUpload)
    }
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        var tag = 0
        tagLock.lock()
        self.tagCount = self.tagCount + 1
        tag = self.tagCount
        tagLock.unlock()
        
        let newClient = HTTPAnalyzer(analyzerDelegate: self, intTag: tag)
        newClient.setSocket(clientSocket: newSocket, socksServerPort: bindToPort)
        
        analyzerLock.lock()
        self.clientSocket.append(newClient)
        DDLogVerbose("H\(newClient.getIntTag())H added into arrary")
        analyzerLock.unlock()
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        NSLog("HTTP Server Disconnected \(err?.localizedDescription ?? "")")
    }
    
    
    func outgoingSocket(didRead data: Data, withTag tag: Int) {
    }
    func outgoingSocket(didWriteDataWithTag tag: Int) {
    }
    func outgoingSocket(didConnectToHost host: String, port: UInt16) {
    }
    
    func outgoingSocketDidDisconnect(_ outgoing: OutgoingSide) {
        let hostAndPort = outgoing.getHostAndPort()
        DDLogVerbose("KAK diddisconnect \(hostAndPort)")
        outgoingStoreLock.lock()
        if var store = outgoingStorage[hostAndPort] {
            if store.count > 1 {
                if let index = store.index(of: outgoing) {
                    DDLogVerbose("KAK removed \(hostAndPort)")
                    store.remove(at: index)
                    outgoingStorage[hostAndPort] = store
                }
            }else{
                DDLogVerbose("KAK empty \(hostAndPort)")
                outgoingStorage.removeValue(forKey: hostAndPort)
            }
        }
        outgoingStoreLock.unlock()
    }
    
    func retrieveOutGoingInstance(byHostNameAndPort hostAndPort: String) -> OutgoingSide? {
        var outgoing: OutgoingSide? = nil
        DDLogVerbose("KAK retrieve \(hostAndPort)")
        outgoingStoreLock.lock()
        if var store = outgoingStorage[hostAndPort] {
            outgoing = store.removeFirst()
            if store.count > 0 {
                outgoingStorage[hostAndPort] = store
            }else{
                outgoingStorage.removeValue(forKey: hostAndPort)
            }
        }
        outgoingStoreLock.unlock()
        
        if outgoing == nil{
            DDLogVerbose("KAK retrieved nil")
        }
        return outgoing
    }
    
    func saveOutgoingSideIntoKeepAliveArray(withHostNameAndPort hostAndPort: String, outgoing: OutgoingSide) {
        if hostAndPort == "" {
            outgoing.setDelegate(nil)
            outgoing.disconnect()
            return
        }
        
        outgoingStoreLock.lock()
        outgoing.setDelegate(self)
        outgoing.setStoreTime()
        outgoing.setHostAndPort(hostAndPort)
        DDLogVerbose("KAK save \(hostAndPort)")
        if var store = outgoingStorage[hostAndPort] {
            store.append(outgoing)
            outgoingStorage[hostAndPort] = store
        }else{
            outgoingStorage[hostAndPort] = [outgoing]
        }
        outgoingStoreLock.unlock()
    }
}
