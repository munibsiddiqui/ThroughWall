//
//  PacketTunnelProvider.swift
//  TWPacketTunnelProvider
//
//  Created by Wu Bin on 16/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import NetworkExtension
import CocoaLumberjack
import SSRLib
import TunnelLib
import Fabric
import Crashlytics

class PacketTunnelProvider: NEPacketTunnelProvider {
    var pendingStartCompletion: ((Error?) -> Void)?
    var pendingStopCompletion: (() -> Void)?
    let ssrControler = SSRLibController()
    var lastPath: NWPath?
    var httpPort = 0

    let filePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/" + configFileName

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        Fabric.with([Crashlytics.self])

        setupDDLog()
        DDLogVerbose("Going to start VPN")
        pendingStartCompletion = completionHandler

        CoreDataController.sharedInstance.closeCrashLogs()
        
//        DDLogVerbose("\(Date().timeIntervalSince1970)")
        Rule.sharedInstance.analyzeRuleFile()
//        DDLogVerbose("\(Date().timeIntervalSince1970)")

        addObserver(self, forKeyPath: "defaultPath", options: NSKeyValueObservingOptions.initial, context: nil)

        //Start shadowsocks_libev
        startShodowsocksClient { (ShadowLibSocksPort, error) in
            if error != nil {
                self.pendingStartCompletion?(error)
                return
            }
            DDLogVerbose("shadowsocks port: \(ShadowLibSocksPort)")
//            DDLogVerbose("\(Date().timeIntervalSince1970)")
            NotificationCenter.default.addObserver(self, selector: #selector(PacketTunnelProvider.onShadowsocksClientClosed), name: NSNotification.Name(rawValue: Tun2SocksStoppedNotification), object: nil)

            //HTTP/HTTPS Proxy Setting
            HTTPProxyManager.shardInstance.startProxy(bindToPort: ShadowLibSocksPort, callback: { (httpProxyPort, error) in

                if error != nil {
                    self.pendingStartCompletion?(error)
                    return
                }
                DDLogVerbose("http(s) port: \(httpProxyPort)")
//                DDLogVerbose("\(Date().timeIntervalSince1970)")
                self.httpPort = httpProxyPort

                //socksTohttp
                Socks2HTTPS.sharedInstance.start(bindToPort: UInt16(httpProxyPort), callback: { (socksPortToHTTP, error) in
                    DDLogVerbose("socksToHTTP port: \(socksPortToHTTP)")
//                    DDLogVerbose("\(Date().timeIntervalSince1970)")
                    //TunnelSetting
                    self.setupTunnelWith(proxyPort: httpProxyPort, completionHandle: { (error) in
                        //Forward IP Packets
                        let error = TunnelManager.sharedInterface().startTunnel(withShadowsocksPort: socksPortToHTTP as NSNumber!, packetTunnelFlow: self.packetFlow)
                        //                        [weakSelf addObserver:weakSelf forKeyPath:@"defaultPath" options:NSKeyValueObservingOptionInitial context:nil];
                        if let _error = error {
                            DDLogVerbose("complete with \(_error)")
                        } else {
                            DDLogVerbose("complete")
                        }
//                        DDLogVerbose("\(Date().timeIntervalSince1970)")
                        self.pendingStartCompletion?(error)

                    })

                })

            })
        }
    }
    
    func setupDDLog() {
        DDLog.add(DDASLLogger.sharedInstance, with: DDLogLevel.warning)// ASL = Apple System Logs

        let fileManager = FileManager.default
        var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName)!
        url.appendPathComponent(PacketTunnelProviderLogFolderName)

        let logFileManager = DDLogFileManagerDefault(logsDirectory: url.path)
        let fileLogger: DDFileLogger = DDFileLogger(logFileManager: logFileManager) // File Logger
        fileLogger.rollingFrequency = TimeInterval(60 * 60) // 1 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 6  // 6 files
        fileLogger.maximumFileSize = 0
        DDLog.add(fileLogger)

        DDLogInfo("------Extension Log Start------")


        let defaults = UserDefaults.init(suiteName: groupName)
        if let logLevel = defaults?.value(forKey: klogLevel) as? String {
            DDLogError("Current Log Level: \(logLevel)")
            switch logLevel.lowercased() {
            case "off":
            defaultDebugLevel = DDLogLevel.off
            case "error":
            defaultDebugLevel = DDLogLevel.error
            case "warning":
            defaultDebugLevel = DDLogLevel.warning
            case "info":
            defaultDebugLevel = DDLogLevel.info
            case "debug":
            defaultDebugLevel = DDLogLevel.debug
            case "verbose":
            defaultDebugLevel = DDLogLevel.verbose
            case"all":
            defaultDebugLevel = DDLogLevel.all
            default:
            defaultDebugLevel = DDLogLevel.debug
            }
        } else {
            defaultDebugLevel = DDLogLevel.debug
            DDLogDebug("Current Log Level: debug")
        }

        DDLogVerbose("\(fileLogger.currentLogFileInfo)")
    }



    func startShodowsocksClient(callback: @escaping (Int, Error?) -> Void) {
        let conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration! as [String: AnyObject]

        let server = conf["server"] as! String
        let port = Int(conf["port"] as! String)
        let password = conf["password"] as! String
        let method = conf["method"] as! String
        let protocol_ssr: String
        if let _protocol = conf["protocol"] as? String {
            protocol_ssr = _protocol
        }else{
            protocol_ssr = ""
        }
        let pro_param: String
        if let _pro_param = conf["proto_param"] as? String {
            pro_param = _pro_param
        }else{
            pro_param = ""
        }
        let obfs: String
        if let _obfs = conf["obfs"] as? String {
            obfs = _obfs
        }else{
            obfs = ""
        }
        let obfs_param: String
        if let _obfs_param = conf["obfs_param"] as? String {
            obfs_param = _obfs_param
        }else{
            obfs_param = ""
        }
//        BOOL ota = [json[@"ota"] boolValue];
        
        ssrControler.startShodowsocksClientWithhostAddress(server, hostPort: NSNumber(value: port!), hostPassword: password, authscheme: method, protocol: protocol_ssr, pro_para: pro_param, obfs: obfs, obfs_para: obfs_param) { (port, error) in
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
        DDLogDebug("StopCompletion")
        DDLog.flushLog()
        if pendingStopCompletion != nil {
            pendingStopCompletion!()
        }
        exit(EXIT_SUCCESS);
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "defaultPath" {
            DDLogDebug("defaultPath")
            if defaultPath?.status == NWPathStatus.satisfied && defaultPath != lastPath {
                if lastPath == nil {
                    lastPath = defaultPath
                } else {
                    DDLogDebug("received network change notification")
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                        self.setupTunnelWith(proxyPort: self.httpPort, completionHandle: { (_) in

                        })
                    })
                }
            } else {
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
