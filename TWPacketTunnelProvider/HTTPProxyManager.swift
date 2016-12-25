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

protocol HTTPAnalyzerDelegate {
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer)
    func didDownloadFromServer(dataSize size: Int, proxyType proxy: String)
    func didUploadToServer(dataSize size: Int, proxyType proxy: String)
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
    private var proxyDownloadCount = 0
    private var directDownloadCount = 0
    private var uploadCount = 0
    private var proxyUploadCount = 0
    private var directUploadCount = 0
    private var secondTimer: DispatchSourceTimer?
    private var hourTimer: DispatchSourceTimer?
    private var tagCount = 0
    
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
        secondTimer?.cancel()
        secondTimer = nil
    }
    
    func prepareTimelyUpdate() {
        secondTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "updateQueue") )
        secondTimer?.scheduleRepeating(deadline: .now() + .seconds(1), interval: .seconds(1), leeway: .milliseconds(100))
        secondTimer?.setEventHandler(handler: {
            let (download, proxyDownload, directDownload, upload, proxyUpload, directUpload) = self.readDownloadUploadCount()
            // DDLogVerbose("download:\(download) upload:\(upload)")
            let defaults = UserDefaults.init(suiteName: groupName)
            
            defaults?.set(download, forKey: downloadCountKey)
            defaults?.set(upload, forKey: uploadCountKey)
            defaults?.synchronize()
            
            let traffic = downUpTraffic(proxyDownload: proxyDownload, directDownload: directDownload, proxyUpload: proxyUpload, directUpload: directUpload)
            
            self.saveTraffic(traffic)
            
            let notification = CFNotificationCenterGetDarwinNotifyCenter()
            
            let name = DarwinNotifications.updateWidget.rawValue
            
            CFNotificationCenterPostNotification(notification, CFNotificationName(name as CFString) , nil, nil, true)
            
        })
        secondTimer?.resume()
        
        setNextHourTimer()
    }
    
    
    func setNextHourTimer() {
        hourTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "hourUpdateQueue"))
        let timeInterval = Int(NSDate().timeIntervalSince1970)
        let leftSecond = 3600 - timeInterval % 3600

        hourTimer?.scheduleOneshot(deadline: .now() + .seconds(leftSecond))
        hourTimer?.setEventHandler(handler: {
            self.setNextHourTimer()
            
            DispatchQueue.main.async {
                let currentTime = NSDate()
                let oldTime = NSDate.init(timeInterval: -3600, since: currentTime as Date)
                
                let fetchOldData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
                fetchOldData.predicate = NSPredicate(format: "timestamp <= %@", oldTime)
                let fetchNewData: NSFetchRequest<HistoryTraffic> = HistoryTraffic.fetchRequest()
                fetchNewData.predicate = NSPredicate(format: "timestamp <= %@", currentTime)
                
                do {
                    let oldData = try CoreDataController.sharedInstance.getContext().fetch(fetchOldData)
                    for data in oldData {
                        CoreDataController.sharedInstance.getContext().delete(data)
                    }
                    CoreDataController.sharedInstance.saveContext()
                    
                    var wifiTraffic = downUpTraffic()
                    var cellularTraffic = downUpTraffic()
                    
                    let newData = try CoreDataController.sharedInstance.getContext().fetch(fetchNewData)
                    for data in newData {
                        switch data.proxyType! {
                        case "Proxy":
                            if data.pathType == "WIFI" {
                                wifiTraffic.proxyUpload = wifiTraffic.proxyUpload + Int(data.outCount)
                                wifiTraffic.proxyDownload = wifiTraffic.proxyDownload + Int(data.inCount)
                            }else if data.pathType == "Cellular" {
                                cellularTraffic.proxyUpload = cellularTraffic.proxyUpload + Int(data.outCount)
                                cellularTraffic.proxyDownload = cellularTraffic.proxyDownload + Int(data.inCount)
                            }
                        case "Direct":
                            if data.pathType == "WIFI" {
                                wifiTraffic.directUpload = wifiTraffic.directUpload + Int(data.outCount)
                                wifiTraffic.directDownload = wifiTraffic.directDownload + Int(data.inCount)
                            }else if data.pathType == "Cellular" {
                                cellularTraffic.directUpload = cellularTraffic.directUpload + Int(data.outCount)
                                cellularTraffic.directDownload = cellularTraffic.directDownload + Int(data.inCount)
                            }
                        default:
                            break
                        }
                    }
                    
                    let timestamp = NSDate()
                    let wifiProxyHisTraffic = HistoryTraffic(context: CoreDataController.sharedInstance.getContext())
                    wifiProxyHisTraffic.hisType = "hour"
                    wifiProxyHisTraffic.proxyType = "Proxy"
                    wifiProxyHisTraffic.pathType = "WIFI"
                    wifiProxyHisTraffic.timestamp = timestamp
                    wifiProxyHisTraffic.inCount = Int64(wifiTraffic.proxyDownload)
                    wifiProxyHisTraffic.outCount = Int64(wifiTraffic.proxyUpload)
                    let wifiDirectHisTraffic = HistoryTraffic(context: CoreDataController.sharedInstance.getContext())
                    wifiDirectHisTraffic.hisType = "hour"
                    wifiDirectHisTraffic.proxyType = "Direct"
                    wifiDirectHisTraffic.pathType = "WIFI"
                    wifiDirectHisTraffic.timestamp = timestamp
                    wifiDirectHisTraffic.inCount = Int64(wifiTraffic.directDownload)
                    wifiDirectHisTraffic.outCount = Int64(wifiTraffic.directUpload)
                    let cellularProxyHisTraffic = HistoryTraffic(context: CoreDataController.sharedInstance.getContext())
                    cellularProxyHisTraffic.hisType = "hour"
                    cellularProxyHisTraffic.proxyType = "Proxy"
                    cellularProxyHisTraffic.pathType = "Cellular"
                    cellularProxyHisTraffic.timestamp = timestamp
                    cellularProxyHisTraffic.inCount = Int64(cellularTraffic.proxyDownload)
                    cellularProxyHisTraffic.outCount = Int64(cellularTraffic.proxyUpload)
                    let celluarDirectHisTraffic = HistoryTraffic(context: CoreDataController.sharedInstance.getContext())
                    celluarDirectHisTraffic.hisType = "hour"
                    celluarDirectHisTraffic.proxyType = "Direct"
                    celluarDirectHisTraffic.pathType = "Cellular"
                    celluarDirectHisTraffic.timestamp = timestamp
                    celluarDirectHisTraffic.inCount = Int64(cellularTraffic.directDownload)
                    celluarDirectHisTraffic.outCount = Int64(cellularTraffic.directUpload)
                    
                    CoreDataController.sharedInstance.saveContext()
                }catch{
                    print(error)
                }
            }
            
            
        })
        
        hourTimer?.resume()
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
            }
            
            if traffic.directDownload > 0 || traffic.directUpload > 0 {
                let directHisTraffic = HistoryTraffic(context: context)
                directHisTraffic.hisType = "second"
                directHisTraffic.inCount = Int64(traffic.directDownload)
                directHisTraffic.outCount = Int64(traffic.directUpload)
                directHisTraffic.proxyType = "Direct"
                directHisTraffic.timestamp = timestamp
                directHisTraffic.pathType = "WIFI"
            }
            
            CoreDataController.sharedInstance.saveContext()
        }
        
    }
    
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer) {
        analyzerLock.lock()
        if let index = self.clientSocket.index(of: analyzer) {
            self.clientSocket.remove(at: index)
            // DDLogVerbose("H\(analyzer.getIntTag()) removed from arrary")
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
        newClient.setSocket(newSocket, socksServerPort: bindToPort)
        analyzerLock.lock()
        self.clientSocket.append(newClient)
        // DDLogVerbose("H\(newClient.getIntTag()) added into arrary")
        analyzerLock.unlock()
    }
    
}
