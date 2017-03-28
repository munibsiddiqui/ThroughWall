//
//  PacketTunnelProvider.swift
//  TWPacketTunnelProvider
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import NetworkExtension
import CocoaLumberjack
import ShadowsocksLib
import TunnelLib
import Fabric
import Crashlytics

class PacketTunnelProvider: NEPacketTunnelProvider {
    var pendingStartCompletion: ((Error?) -> Void)?
    var pendingStopCompletion: (() -> Void)?
    let ssControler = SSlibevController()
    var lastPath: NWPath?
    var httpPort = 0
    
    let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + configFileName
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        Fabric.with([Crashlytics.self])
        
        DDLog.add(DDASLLogger.sharedInstance) // ASL = Apple System Logs
        
        let fileManager = FileManager.default
        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(PacketTunnelProviderLogFolderName)
        
        let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
        let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger
        fileLogger.rollingFrequency = TimeInterval(60*60*24)  // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 0
        DDLog.add(fileLogger)
        
        defaultDebugLevel = DDLogLevel.verbose
        
        DDLogInfo("------Log Start------")
        DDLogVerbose("\(fileLogger.currentLogFileInfo)")
        DDLogVerbose("Going to start VPN")
        
        pendingStartCompletion = completionHandler
        
        Rule.sharedInstance.analyzeRuleFile()
        
        addObserver(self, forKeyPath: "defaultPath", options: NSKeyValueObservingOptions.initial, context: nil)
        
        //Start shadowsocks_libev
        startShodowsocksClient { (ShadowLibSocksPort, error) in
            if error != nil {
                self.pendingStartCompletion?(error)
                return
            }
            DDLogVerbose("shadowsocks port: \(ShadowLibSocksPort)")
            
            NotificationCenter.default.addObserver(self, selector: #selector(PacketTunnelProvider.onShadowsocksClientClosed), name: NSNotification.Name(rawValue: Tun2SocksStoppedNotification), object: nil)
            
            //HTTP/HTTPS Proxy Setting
            HTTPProxyManager.shardInstance.startProxy(bindToPort: ShadowLibSocksPort, callback: { (httpProxyPort, error) in
                
                if error != nil {
                    self.pendingStartCompletion?(error)
                    return
                }
                DDLogVerbose("http(s) port: \(httpProxyPort)")
                self.httpPort = httpProxyPort
                
                //socksTohttp
                Socks2HTTPS.sharedInstance.start(bindToPort: UInt16(httpProxyPort), callback: { (socksPortToHTTP, error) in
                    DDLogVerbose("socksToHTTP port: \(socksPortToHTTP)")
                    //TunnelSetting
                    self.setupTunnelWith(proxyPort: httpProxyPort, completionHandle: { (error) in
                        //Forward IP Packets
                        let error = TunnelManager.sharedInterface().startTunnel(withShadowsocksPort: socksPortToHTTP as NSNumber!, packetTunnelFlow: self.packetFlow)
                        //                        [weakSelf addObserver:weakSelf forKeyPath:@"defaultPath" options:NSKeyValueObservingOptionInitial context:nil];
                        self.pendingStartCompletion?(error)
                        
                    })
                    
                })
                
            })
        }
    }
    
    
    func startShodowsocksClient(callback: @escaping (Int, Error?) -> Void) {
        let conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration! as [String : AnyObject]
        
        let server = conf["server"] as! String
        let port = Int(conf["port"] as! String)
        let password = conf["password"] as! String
        let method = conf["method"] as! String
        
        ssControler.startShodowsocksClientWithhostAddress(server, hostPort: NSNumber(value: port!), hostPassword: password, authscheme: method) { (port, error) in
            callback(Int(port), error)
        }
    }
    
    func setupTunnelWith(proxyPort port: Int, completionHandle: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "192.0.2.2")
        
        let ipv4Setting = NEIPv4Settings(addresses: ["192.0.2.1"], subnetMasks: ["255.255.255.0"])
        ipv4Setting.includedRoutes = [NEIPv4Route.default()]
        
        settings.iPv4Settings = ipv4Setting
        settings.mtu = 1600
        
        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "localhost", port: port)
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "localhost", port: port)
        proxySettings.excludeSimpleHostnames = true
        
        settings.proxySettings = proxySettings
        let dnsSetting = NEDNSSettings.init(servers: DNSConfig.getSystemDnsServers() as! [String])
        dnsSetting.matchDomains = [""]
        settings.dnsSettings = dnsSetting
        
        self.setTunnelNetworkSettings(settings) { (error) in
            completionHandle(error)
        }
    }
    
    func onShadowsocksClientClosed() {
        DDLogDebug("onShadowsocksClientClosed")
        HTTPProxyManager.shardInstance.stopProxy()        
        if pendingStopCompletion != nil {
            pendingStopCompletion!()
        }
        exit(EXIT_SUCCESS);
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "defaultPath" {
            DDLogDebug("defaultPath")
            if defaultPath?.status == NWPathStatus.satisfied && defaultPath != lastPath {
                if lastPath == nil {
                    lastPath = defaultPath
                }else{
                    DDLogDebug("received network change notifcation")
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                        self.setupTunnelWith(proxyPort: self.httpPort, completionHandle: { (_) in
                            
                        })
                    })
                }
            }else{
                lastPath = defaultPath
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        TunnelManager.sharedInterface().stop()
        pendingStopCompletion = completionHandler
        DDLogDebug("stopTunnel")
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
