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
    func retrieveOutGoingInstance(byHostNameAndPort hostAndPort: String) -> OutgoingSide?
    func saveOutgoingSideIntoKeepAliveArray(withHostNameAndPort hostAndPort: String, outgoing: OutgoingSide)
}

class HTTPProxyManager: NSObject {

    static let shardInstance = HTTPProxyManager()

    fileprivate var bindToPort = 0
    private var socketServer: GCDAsyncSocket!
    fileprivate var clientSocket = [HTTPAnalyzer]()
    fileprivate let analyzerLock = NSLock()
    fileprivate let downloadLock = NSLock()
    fileprivate let uploadLock = NSLock()
    fileprivate let tagLock = NSLock()
    fileprivate var clientEmptySemaphore: DispatchSemaphore? =  nil
    
    fileprivate let outgoingStoreLock = NSLock()
//    private var downloadCount = 0
    fileprivate var proxyDownloadCount = 0
    fileprivate var directDownloadCount = 0
//    private var uploadCount = 0
    fileprivate var proxyUploadCount = 0
    fileprivate var directUploadCount = 0
    private var saveTrafficTimer: DispatchSourceTimer?
    private var repeatDeleteTimer: DispatchSourceTimer?
    private var repeatDisconnectTimer: DispatchSourceTimer?
    fileprivate var tagCount = 0
    
    fileprivate var outgoingStorage = [String: [OutgoingSide]]()
    struct downUpTraffic {
        var proxyDownload = 0
        var directDownload = 0
        var proxyUpload = 0
        var directUpload = 0
    }

    // MARK: - start & stop Http(s) Proxy

    func startProxy(bindToPort toPort: Int, callback: (Int, Error?) -> Void) {
        let localPort = 0
        bindToPort = toPort

        socketServer = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.global())
        do {
            try socketServer.accept(onInterface: "127.0.0.1", port: UInt16(localPort))
        } catch {
            callback(0, error)
            return
        }
        prepareTimelyUpdate()
        callback(Int(socketServer.localPort), nil)
    }

    func stopProxy() {
        socketServer.disconnect()

        analyzerLock.lock()
        
        if clientSocket.count > 0 {
            DDLogVerbose("client count: \(clientSocket.count)")
            clientEmptySemaphore = DispatchSemaphore(value: 0)
            for client in clientSocket {
                client.forceDisconnect()
            }
        }
        analyzerLock.unlock()
//        while true {
//            if clientSocket.count == 0 {
//                break
//            }
//        }

        DDLogVerbose("wait for all disconnected")
        clientEmptySemaphore?.wait()
        clientEmptySemaphore = nil
        DDLogVerbose("continue~~~")
        
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

    // MARK: - -

    func prepareTimelyUpdate() {
        repeatlySaveTraffic(withInterval: 1)
        repeatlyDeleteOldHistory(before: 12 * 3600, withRepeatPeriod: 100)
        repeatlyDisconnectOutgoing(withMaxKeepAliveTime: 60, checkPeriod: 10)
    }

    // MARK: - repeatlySaveTraffic

    func repeatlySaveTraffic(withInterval interval: Int) {
        saveTrafficTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "saveQueue"))
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
                    let pUpload = defaults?.value(forKey: proxyUploadCountKey) as? Int ?? 0
                    defaults?.set(pDownload + proxyDownload, forKey: proxyDownloadCountKey)
                    defaults?.set(pUpload + proxyUpload, forKey: proxyUploadCountKey)
                } else {
                    let oldProxyDownload = defaults?.value(forKey: proxyDownloadCountKey) as! Int
                    let oldProxyUpload = defaults?.value(forKey: proxyUploadCountKey) as! Int
                    let oldDate = localFormatter.date(from: recordingDate)
                    self.archiveOldMonthHistory(oldProxyDownload, oldProxyUpload: oldProxyUpload, oldDate: oldDate! as NSDate)
                    defaults?.set(proxyDownload, forKey: proxyDownloadCountKey)
                    defaults?.set(proxyUpload, forKey: proxyUploadCountKey)
                    defaults?.set(currentDate, forKey: recordingDateKey)
                }
            } else {
                defaults?.set(proxyDownload, forKey: proxyDownloadCountKey)
                defaults?.set(proxyUpload, forKey: proxyUploadCountKey)
                defaults?.set(currentDate, forKey: recordingDateKey)
            }

            defaults?.set(Date(), forKey: currentTime)
            
            defaults?.synchronize()

            let traffic = downUpTraffic(proxyDownload: proxyDownload, directDownload: directDownload, proxyUpload: proxyUpload, directUpload: directUpload)

            self.saveTraffic(traffic)

            let notification = CFNotificationCenterGetDarwinNotifyCenter()

            let name = DarwinNotifications.updateWidget.rawValue

            CFNotificationCenterPostNotification(notification, CFNotificationName(name as CFString), nil, nil, true)

        })
        saveTrafficTimer?.resume()
    }

    func readDownloadUploadCount() -> (Int, Int, Int, Int, Int, Int) {
        var download = 0
        var proxyDownload = 0
        var directDownload = 0
        var upload = 0
        var proxyUpload = 0
        var directUpload = 0
        downloadLock.lock()
        download = self.proxyDownloadCount + self.directDownloadCount //self.downloadCount
        proxyDownload = self.proxyDownloadCount
        directDownload = self.directDownloadCount
        //        self.downloadCount = 0
        self.proxyDownloadCount = 0
        self.directDownloadCount = 0
        downloadLock.unlock()
        uploadLock.lock()
        upload = self.proxyUploadCount + self.directUploadCount //self.uploadCount
        proxyUpload = self.proxyUploadCount
        directUpload = self.directUploadCount
        //        self.uploadCount = 0
        self.proxyUploadCount = 0
        self.directUploadCount = 0
        uploadLock.unlock()
        return (download, proxyDownload, directDownload, upload, proxyUpload, directUpload)
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

    func saveTraffic(_ traffic: downUpTraffic) {
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

    // MARK: - repeatlyDeleteOldHistory

    func repeatlyDeleteOldHistory(before beforeSeconds: Int, withRepeatPeriod repeatPeriod: Int) {
        repeatDeleteTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "deleteQueue"))
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
                } catch {
                    DDLogError("repeatlyDeleteOldHistory \(error)")
                }
            }
        })
        repeatDeleteTimer?.resume()
    }

    // MARK: - repeatlyDisconnectOutgoing
    func repeatlyDisconnectOutgoing(withMaxKeepAliveTime maxAliveTime: Int, checkPeriod: Int) {
        repeatDisconnectTimer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue(label: "disconnectQueue"))
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

}

// MARK: - HTTPAnalyzerDelegate

extension HTTPProxyManager: HTTPAnalyzerDelegate {
    func HTTPAnalyzerDidDisconnect(httpAnalyzer analyzer: HTTPAnalyzer) {
        analyzerLock.lock()
        if let index = clientSocket.index(of: analyzer) {
            clientSocket.remove(at: index)
            DDLogVerbose("H\(analyzer.getIntTag())H removed from array. \(clientSocket.count)")
        } else {
            DDLogError("H\(analyzer.getIntTag())H can't find in the array")
        }
        
        if clientSocket.count == 0 {
            clientEmptySemaphore?.signal()
        }
        
        analyzerLock.unlock()
    }

    func didDownloadFromServer(dataSize size: Int, proxyType proxy: String) {
        downloadLock.lock()
//        self.downloadCount = self.downloadCount + size
        switch proxy.lowercased() {
        case "proxy":
            self.proxyDownloadCount = self.proxyDownloadCount + size
        case "direct":
            self.directDownloadCount = self.directDownloadCount + size
        default:
            break
        }
        downloadLock.unlock()
    }

    func didUploadToServer(dataSize size: Int, proxyType proxy: String) {
        uploadLock.lock()
//        self.uploadCount = self.uploadCount + size
        switch proxy.lowercased() {
        case "proxy":
            self.proxyUploadCount = self.proxyUploadCount + size
        case "direct":
            self.directUploadCount = self.directUploadCount + size
        default:
            break
        }
        uploadLock.unlock()
    }

    func retrieveOutGoingInstance(byHostNameAndPort hostAndPort: String) -> OutgoingSide? {
        var outgoing: OutgoingSide? = nil
        DDLogVerbose("KAK retrieve \(hostAndPort)")
        outgoingStoreLock.lock()
        if var store = outgoingStorage[hostAndPort] {
            outgoing = store.removeFirst()
            if store.count > 0 {
                outgoingStorage[hostAndPort] = store
            } else {
                outgoingStorage.removeValue(forKey: hostAndPort)
            }
        }
        outgoingStoreLock.unlock()

        if outgoing == nil {
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
        } else {
            outgoingStorage[hostAndPort] = [outgoing]
        }
        outgoingStoreLock.unlock()
    }

}

// MARK: - OutgoingTransmitDelegate

extension HTTPProxyManager: OutgoingTransmitDelegate {

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
            } else {
                DDLogVerbose("KAK empty \(hostAndPort)")
                outgoingStorage.removeValue(forKey: hostAndPort)
            }
        }
        outgoingStoreLock.unlock()
    }
}


// MARK: - GCDAsyncSocketDelegate

extension HTTPProxyManager: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {

        let tag = getNewTagNumber()

        let newClient = HTTPAnalyzer(analyzerDelegate: self, intTag: tag)
        newClient.setSocket(clientSocket: newSocket, socksServerPort: bindToPort)

        analyzerLock.lock()
        clientSocket.append(newClient)
        DDLogVerbose("H\(newClient.getIntTag())H added into array. \(clientSocket.count)")
        analyzerLock.unlock()
    }

    func getNewTagNumber() -> Int {
        var tag = 0
        tagLock.lock()
        tagCount = tagCount + 1
        tag = tagCount
        tagLock.unlock()
        return tag
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        NSLog("HTTP Server Disconnected \(err?.localizedDescription ?? "")")
    }
}


