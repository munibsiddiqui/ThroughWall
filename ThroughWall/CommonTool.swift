//
//  CommonTool.swift
//  ThroughWall
//
//  Created by Bin on 28/04/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Foundation
import NetworkExtension
import CocoaLumberjack

let CustomizeOption = "Custom"

class ProxyConfig: NSObject {

    private let proxies = ["CUSTOM", "HTTP", "SOCKS5"]

    private let items = [
        "CUSTOM": ["proxy", "description", "server", "port", "password", "method", "protocol", "obfs", "obfs_param"],
        "HTTP": ["proxy", "description", "server", "port", "user", "password"],
        "SOCKS5": ["proxy", "description", "server", "port", "user", "password"]
    ]

    private let hiddenItems = [
        "CUSTOM": ["delay"],
    ]

    private let defaults = [
        "CUSTOM": ["proxy": "CUSTOM", "method": "aes-256-cfb", "dns": "System Default", "protocol": "", "obfs": ""],
        "HTTP": ["proxy": "HTTP"],
        "SOCKS5": ["proxy": "SOCKS5"]
    ]

    private let availables = [
        "CUSTOM": [
            "proxy": [
                "preset": [
                    "CUSTOM"//, "HTTP", "SOCKS5"
                ]
            ],
            "method": [
                "preset": [
                    "table", "aes-128-ctr", "aes-192-ctr", "aes-256-ctr", "aes-128-cfb", "aes-192-cfb", "aes-256-cfb", "bf-cfb", "camellia-128-cfb", "camellia-192-cfb", "camellia-256-cfb", "cast5-cfb", "chacha20", "chacha20-ietf", "des-cfb", "idea-cfb", "rc2-cfb", "rc4", "rc4-md5", "salsa20", "seed-cfb"
                ]
            ],
            "dns": [
                "preset": [
                    "System Default"
                ],
                "customize": [
                    CustomizeOption
                ]
            ],
            "protocol": [
                "preset": [
                    "", "origin", "tls1.2_ticket_auth", "verify_simple", "auth_simple", "auth_sha1", "auth_sha1_v2"
                ]
            ],
            "obfs": [
                "preset": [
                    "", "plain", "http_simple", "tls1.2_ticket_auth"
                ]
            ]
        ],
        "HTTP": [
            "proxy": [
                "preset": [
                    "CUSTOM", "HTTP", "SOCKS5"
                ]
            ]
        ],
        "SOCKS5": [
            "proxy": [
                "preset": [
                    "CUSTOM", "HTTP", "SOCKS5"
                ]
            ]
        ]
    ]

    private let keyboadType = [
        "CUSTOM": [
            "description": ["default", "next"],
            "server": ["url", "next"],
            "port": ["number", "accessary", "next"],
            "password": ["default", "secure", "next"],
            "obfs_param": ["default", "done"]
        ]
    ]

    let shownName = [
        "proxy": "ProxyType",
        "description": "Description",
        "server": "Server",
        "port": "Port",
        "user": "User",
        "password": "Password",
        "method": "Method",
        //        "dns": "DNS"
        "protocol": "Protocol(SSR)",
        "obfs": "Ofbs(SSR)",
        "obfs_param": "Obfs Param(SSR)"
    ]

    private var _currentProxy = ""
    private var _containedItems = [String]()
    private var _containedHiddenItems = [String]()
    private var _values = [String: String]()
    private var _availableOptions = [String: [String: [String]]]()
    private var _keyboardType = [String: [String]]()
    var currentProxy: String {
        set {
            if proxies.contains(newValue) {
                if _currentProxy == newValue {
                    return
                }
                _currentProxy = newValue
                if let items = items[currentProxy] {
                    _containedItems = items
                }
                if let items = hiddenItems[currentProxy] {
                    _containedHiddenItems = items
                }
                if let defaults = defaults[currentProxy] {
                    _values = defaults
                }
                if let availavles = availables[currentProxy] {
                    _availableOptions = availavles
                }
                if let keyboadType = keyboadType[currentProxy] {
                    _keyboardType = keyboadType
                }
            }
        }
        get {
            return _currentProxy
        }
    }

    var containedItems: [String] {
        return _containedItems
    }

    var containedHiddenItems: [String] {
        return _containedHiddenItems
    }

    func setValue(byItem item: String, value: String) {
        _values[item] = value
    }

    func getValue(byItem item: String) -> String? {
        return _values[item]
    }

    func getAvailableOptions(byItem item: String) -> ([String], [String])? {

        if let itemOptions = _availableOptions[item] {
            var preset = [String]()
            var customize = [String]()
            if let temp = itemOptions["preset"] {
                preset = temp
            }
            if let cust = itemOptions["customize"] {
                customize = cust
            }
            return (preset, customize)

        } else {
            return nil
        }
    }

    func getKeyboardType(byItem item: String) -> [String]? {
        return _keyboardType[item]
    }

    func setCustomOption(byItem item: String, option: String) {
        _availableOptions[item]?["customize"] = [option]
    }

    func setSelection(_ item: String, selected value: String) {
        //        print("\(item) \(selected)")
        if item == "proxy" {
            currentProxy = value
            return
        }
        _values[item] = value
        if !_availableOptions[item]!["preset"]!.contains(value) {
            setCustomOption(byItem: item, option: value)
        }
    }

}

class SiteConfigController {

    enum ServerVersionStatus {
        case ERROR
        case EMPTY
        case CONVERTED
        case NOTCONVERTED
    }

    private func isContainConvertedVPN(amongManagers managers: [NETunnelProviderManager]) -> Bool {
        for vpnManager in managers {
            if let providerProtocol = vpnManager.protocolConfiguration as? NETunnelProviderProtocol {
                if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                    return true
                }
            }
        }
        return false
    }

    private func checkServerStatus(withCompletionHandler completion: @escaping (ServerVersionStatus, [NETunnelProviderManager]) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            if error == nil {
                guard let vpnManagers = newManagers else {
                    completion(ServerVersionStatus.EMPTY, [NETunnelProviderManager]())
                    return
                }

                if vpnManagers.count < 1 {
                    completion(ServerVersionStatus.EMPTY, [NETunnelProviderManager]())
                    return
                }

                if self.isContainConvertedVPN(amongManagers: vpnManagers) {
                    completion(ServerVersionStatus.CONVERTED, vpnManagers)
                } else {
                    completion(ServerVersionStatus.NOTCONVERTED, vpnManagers)
                }
            } else {
                DDLogError("\(error!)")
                completion(ServerVersionStatus.ERROR, [NETunnelProviderManager]())
            }
        }
    }

    private func getConfig(fromManager mamager: NETunnelProviderManager) -> ProxyConfig? {

        if var proxy = (mamager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!["proxy"] as? String {
            if proxy == "SHADOWSOCKS" {
                proxy = "CUSTOM"
            }
            let proxyConfig = ProxyConfig()
            proxyConfig.currentProxy = proxy

            for item in proxyConfig.containedItems {
                if var value = (mamager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration![item] as? String {
                    if value == "SHADOWSOCKS" {
                        value = "CUSTOM"
                    }
                    proxyConfig.setValue(byItem: item, value: value)
                }
            }
            return proxyConfig
        }
        return nil
    }

    private func setConfig(fromProxyConfig config: ProxyConfig, toManager manager: NETunnelProviderManager) {

        var configuration = [String: AnyObject]()

        let items = config.containedItems

        for item in items {
            configuration[item] = config.getValue(byItem: item) as AnyObject?
        }
        configuration[kConfigureVersion] = currentConfigureVersion as AnyObject?
        (manager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration = configuration
    }


    private func saveConfigFile(fromOldVPNManagers managers: [NETunnelProviderManager]) {
        var proxyConfigs = [ProxyConfig]()
        var index = 0
        for manager in managers {
            if let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol {
                if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                } else {
                    if let conf = self.getConfig(fromManager: manager) {
                        if manager.isEnabled {
                            setSelectedServerIndex(withValue: index)
                        }
                        proxyConfigs.append(conf)
                        index = index + 1
                    }
                }
            }
        }
        if proxyConfigs.count > 0 {
            self.writeIntoSiteConfigFile(withConfigs: proxyConfigs)
            DDLogInfo("save config file")
        }
    }

    private func deleteOldServer(fromVPNManagers managers: [NETunnelProviderManager]) -> NETunnelProviderManager? {
        var newVersionManager: NETunnelProviderManager? = nil
        for manager in managers {
            if let providerProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol {
                if let _ = providerProtocol.providerConfiguration?[kConfigureVersion] {
                    newVersionManager = manager
                } else {
                    //delete old
                    manager.removeFromPreferences(completionHandler: nil)
                    DDLogInfo("delete old")
                }
            }
        }
        return newVersionManager
    }

    private func createNewTypeServer(withCompeletionHandler completionHandler: @escaping (NETunnelProviderManager?) -> Void) {
        //no saved. create one
        let manager = NETunnelProviderManager()
        manager.loadFromPreferences { error in

            if error != nil {
                DDLogError("loadFromPreferences \(error!)")
                completionHandler(nil)
                return
            }

            let providerProtocol = NETunnelProviderProtocol()
            providerProtocol.providerBundleIdentifier = kTunnelProviderBundle
            providerProtocol.providerConfiguration = [kConfigureVersion: currentConfigureVersion]
            manager.protocolConfiguration = providerProtocol
            manager.protocolConfiguration?.serverAddress = "10.0.0.0"
            manager.localizedDescription = "Chisel"
//            manager.saveToPreferences() { error in
//                if error != nil {
//                    print("save new manager \(error!)")
//                    completionHandler(nil)
//                } else {
//                    print("saved new manager")
//                    completionHandler(manager)
//                }
//            }
            completionHandler(manager)
        }
    }

    func writeIntoSiteConfigFile(withConfigs configs: [ProxyConfig]) {
        let fileManager = FileManager.default

        guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return
        }
        url.appendPathComponent(siteFileName)

        do {

            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }

            fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
            let filehandle = try FileHandle(forWritingTo: url)

            for config in configs {

                var items = config.containedItems
                //the first item should be proxy !!!
                for item in items {
                    if let value = config.getValue(byItem: item) {
                        filehandle.write("\(item):\(value)\n".data(using: String.Encoding.utf8)!)
                    }
                }

                items = config.containedHiddenItems
                for item in items {
                    if let value = config.getValue(byItem: item) {
                        filehandle.write("\(item):\(value)\n".data(using: String.Encoding.utf8)!)
                    }
                }


                filehandle.write("#\n".data(using: String.Encoding.utf8)!)
            }

            filehandle.synchronizeFile()

        } catch {
            DDLogError("\(error)")
            return
        }
    }

    func convertOldServer(withCompletionHandler completion: @escaping (NETunnelProviderManager?) -> Void) {
        checkServerStatus { (currentStatus, vpnManagers) in
            switch currentStatus {
            case .ERROR:
                DDLogError("Unknow")
                completion(nil)
            case .EMPTY:
                DDLogInfo("empty")
                completion(nil)
            case .CONVERTED:
                DDLogInfo("converted")
                let newVersionManager = self.deleteOldServer(fromVPNManagers: vpnManagers)
                completion(newVersionManager)
            case .NOTCONVERTED:
                DDLogInfo("not converted")
                self.saveConfigFile(fromOldVPNManagers: vpnManagers)
                self.createNewTypeServer { _newManager in
                    let _ = self.deleteOldServer(fromVPNManagers: vpnManagers)
                    let proxyConfigs = self.readSiteConfigsFromConfigFile()
                    if let newManager = _newManager {
                        if let selectedIndex = self.getSelectedServerIndex() {
                            self.save(withConfig: proxyConfigs[selectedIndex], intoManager: newManager, completionHander: {
                                completion(newManager)
                            })
                        } else {
                            self.save(withConfig: proxyConfigs[0], intoManager: newManager, completionHander: {
                                completion(newManager)
                            })
                        }
                    }

                }
            }
        }
    }

    func save(withConfig config: ProxyConfig, intoManager manager: NETunnelProviderManager, completionHander completion: @escaping (Void) -> Void) {
        self.setConfig(fromProxyConfig: config, toManager: manager)

        manager.isEnabled = true
        manager.saveToPreferences(completionHandler: { (_error) in
            if let error = _error {
                DDLogError("save failed: \(error)")
            }
            completion()
        })
    }

    func forceSaveToManager(withConfig config: ProxyConfig, withCompletionHandler completion: @escaping (NETunnelProviderManager?) -> Void) {
        checkServerStatus { (status, vpnManagers) in
            switch status {
            case .ERROR:
                completion(nil)
            case .EMPTY:
                self.createNewTypeServer { _newManager in
                    if let newManager = _newManager {
                        self.save(withConfig: config, intoManager: newManager, completionHander: {
                            completion(newManager)
                        })
                    } else {
                        completion(nil)
                    }
                }
            case .CONVERTED:
                let manager = vpnManagers[0]
                self.save(withConfig: config, intoManager: manager, completionHander: {
                    completion(manager)
                })
            case .NOTCONVERTED:
                //impossible
                completion(nil)
            }
        }
    }

    func readSiteConfigsFromConfigFile() -> [ProxyConfig] {
        var proxyConfigs = [ProxyConfig]()

        let fileManager = FileManager.default

        guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return proxyConfigs
        }

        url.appendPathComponent(siteFileName)
        if !fileManager.fileExists(atPath: url.path) {
            return proxyConfigs
        }

        do {

            let content = try String(contentsOf: url, encoding: String.Encoding.utf8)
            let sites = content.components(separatedBy: "#\n")
            for site in sites {
                var items = site.components(separatedBy: "\n")
                let config = ProxyConfig()

                let firstItem = items[0]

                if firstItem.hasPrefix("proxy:") {
                    config.currentProxy = firstItem.substring(from: firstItem.index(firstItem.startIndex, offsetBy: 6))
                    items.removeFirst()
                    items.removeLast()

                    for item in items {
                        let temp = item.components(separatedBy: ":")
                        let name = temp[0]
                        // let option = temp.count > 2 ? temp.dropFirst().joined(separator: ":") : temp[1]
                        let option: String

                        if temp.count > 2 {
                            option = temp.dropFirst().joined(separator: ":")
                        } else {
                            option = temp[1]
                        }

                        if config.containedItems.contains(name) || config.containedHiddenItems.contains(name) {
                            config.setValue(byItem: name, value: option)
                        }
                    }
                    proxyConfigs.append(config)
                }
            }
        } catch {
            DDLogError("\(error)")
        }

        return proxyConfigs
    }


    func getSelectedServerIndex() -> Int? {
        let defaults = UserDefaults.init(suiteName: groupName)

        if let index = defaults?.value(forKey: kSelectedServerIndex) as? Int {
            return index
        }
        return nil
    }

    func setSelectedServerIndex(withValue value: Int) {
        let defaults = UserDefaults.init(suiteName: groupName)

        defaults?.set(value, forKey: kSelectedServerIndex)
    }

}


class QRCodeProcess {
    private var proxyConfig: ProxyConfig? = nil


    // decode

    func decode(QRCode code: String, intoProxyConfig proxyConfig: ProxyConfig) -> (ProxyConfig, Bool) {
        self.proxyConfig = proxyConfig
        var code = code
        let succeed: Bool
        if let preRange = code.range(of: "ssr://") {
            code.removeSubrange(preRange)
            succeed = SSRDecode(withCode: code)
        } else if let preRange = code.range(of: "ss://") {
            code.removeSubrange(preRange)
            succeed = SSDecode(withCode: code)
        } else {
            succeed = false
        }

        return (self.proxyConfig!, succeed)
    }

    private func SSRDecode(withCode code: String) -> Bool {
        //host:port:protocol:method:obfs:base64pass/?obfsparam=base64param&protoparam=base64param&remarks=base64remarks&group=base64group&udpport=0&uot=0
        if let decodestring = decodeUsingBase64(code) {
            DDLogDebug(decodestring)
            let parts = decodestring.components(separatedBy: "/?")
            if extractSSR(requiredPart: parts[0]) {
                extractSSR(optionPart: parts[1])
                return true
            }
        }

        return false
    }

    private func extractSSR(requiredPart rPart: String) -> Bool {
        let parts = rPart.components(separatedBy: ":")
        if parts.count == 6 {
            if let password = decodeUsingBase64(parts[5]) {
                proxyConfig?.setValue(byItem: "server", value: parts[0])
                proxyConfig?.setValue(byItem: "port", value: parts[1])
                proxyConfig?.setValue(byItem: "protocol", value: parts[2])
                proxyConfig?.setValue(byItem: "method", value: parts[3])
                proxyConfig?.setValue(byItem: "obfs", value: parts[4])
                proxyConfig?.setValue(byItem: "password", value: password)
                proxyConfig?.setValue(byItem: "description", value: "\(parts[0]):\(parts[1])")
                return true
            }
        }
        return false
    }

    private func extractSSR(optionPart oPart: String) {
        let parts = oPart.components(separatedBy: "&")
        for part in parts {
            let items = part.components(separatedBy: "=")
            if items.count == 2 {
                if let param = decodeUsingBase64(items[1]) {
                    switch items[0] {
                    case "obfsparam":
                        proxyConfig?.setValue(byItem: "obfs_param", value: param)
                    case "protoparam":
                        proxyConfig?.setValue(byItem: "proto_param", value: param)
                    case "remarks":
                        proxyConfig?.setValue(byItem: "description", value: param)
                    case "group":
                        proxyConfig?.setValue(byItem: "group", value: param)
                    default:
                        break
                    }
                }
            }
        }
    }


    private func SSDecode(withCode code: String) -> Bool {
        let desciption: String
        var code = code

        if let poundsignIndex = code.range(of: "#")?.lowerBound {
            let removeRange = Range(uncheckedBounds: (lower: poundsignIndex, upper: code.endIndex))
            desciption = code.substring(from: code.index(after: poundsignIndex))
            code.removeSubrange(removeRange)
        } else {
            desciption = ""
        }

        if let decodestring = decodeUsingBase64(code) {
            DDLogDebug(decodestring)
            let components = decodestring.components(separatedBy: ":")
            if components.count == 3 {
                var method = components[0]
                let passwordHost = components[1]
                let port = components[2]

                let components2 = passwordHost.components(separatedBy: "@")
                if components2.count == 2 {
                    let password = components2[0]
                    let host = components2[1]

                    if let range = method.range(of: "-auth") {
                        method.removeSubrange(range)
                    }

                    if desciption == "" {
                        proxyConfig?.setValue(byItem: "description", value: "\(host):\(port)")
                    } else {
                        proxyConfig?.setValue(byItem: "description", value: desciption)
                    }
                    proxyConfig?.setValue(byItem: "server", value: host)
                    proxyConfig?.setValue(byItem: "port", value: port)
                    proxyConfig?.setValue(byItem: "password", value: password)
                    proxyConfig?.setValue(byItem: "method", value: method)

                    return true
                }
            }
        }
        return false
    }

    private func decodeUsingBase64(_ string: String) -> String? {
        var str = string
        str = str.padding(toLength: ((str.characters.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        let decodeData = Data.init(base64Encoded: str)
        if let decodestring = String(data: decodeData ?? Data(), encoding: String.Encoding.utf8) {
            return decodestring
        }
        return nil
    }


    //  encode

    func getEncodedServerInfo(withProxyConfig proxyConfig: ProxyConfig) -> String {
        self.proxyConfig = proxyConfig

        if let value = proxyConfig.getValue(byItem: "protocol") {
            if value != "" {
                return getEncodedSSRServerInfo()
            }
        }

        return getEncodedSSServerInfo()
    }

    private func getEncodedSSRServerInfo() -> String {
        //host:port:protocol:method:obfs:base64pass/?obfsparam=base64param&protoparam=base64param&remarks=base64remarks&group=base64group&udpport=0&uot=0
        if let rPart = encodeSSRRequiedPart() {
            let content = rPart + "/?" + encodeSSROptionPart()
            DDLogDebug(content)
            return "ssr://" + encodeUsingBase64(content)
        }
        return ""
    }

    private func encodeSSRRequiedPart() -> String? {
        let partRItems = ["server", "port", "protocol", "method", "obfs"]
        var rValues = [String]()
        for item in partRItems {
            if let value = proxyConfig?.getValue(byItem: item) {
                rValues.append(value)
            } else {
                return nil
            }
        }
        if let value = proxyConfig?.getValue(byItem: "password") {
            rValues.append(encodeUsingBase64(value))
        } else {
            return nil
        }
        return rValues.joined(separator: ":")
    }

    private func encodeSSROptionPart() -> String {
        let oItems = [["obfs_param", "obfsparam"], ["proto_param", "protoparam"], ["description", "remarks"], ["grpup", "group"]]
        var oValues = [String]()
        for item in oItems {
            if let value = proxyConfig?.getValue(byItem: item[0]) {
                if value != "" {
                    oValues.append("\(item[1])=\(encodeUsingBase64(value))")
                }
            }
        }
        return oValues.joined(separator: "&")
    }


    private func getEncodedSSServerInfo() -> String {
        var result = ""

        if let value = proxyConfig?.getValue(byItem: "method") {
            result = value
        } else {
            return ""
        }
        if let value = proxyConfig?.getValue(byItem: "password") {
            result = result + ":" + value
        } else {
            return ""
        }
        if let value = proxyConfig?.getValue(byItem: "server") {
            result = result + "@" + value
        } else {
            return ""
        }
        if let value = proxyConfig?.getValue(byItem: "port") {
            result = result + ":" + value
        } else {
            return ""
        }

        DDLogDebug("\(result)")
        result = encodeUsingBase64(result)
        if let value = proxyConfig?.getValue(byItem: "description") {
            let tmp = result + "#" + value
            DDLogDebug(tmp)
            result = "ss://" + result + "#" + value
        }
        return result
    }

    func encodeUsingBase64(_ string: String) -> String {
        let utf8Str = string.data(using: .utf8)
        if var base64Encoded = utf8Str?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) {
            while base64Encoded.hasSuffix("=") {
                base64Encoded.remove(at: base64Encoded.index(before: base64Encoded.endIndex))
            }
            return base64Encoded
        }
        return ""
    }

}


class RuleFileUpdateController: NSObject {

    func tryUpdateRuleFileFromBundleFile() {
        if getCurrentFileSource() == defaultFileSource {
            if isBundleRuleFileNewer() {
                updateRuleFileFromBundleFile()
            }
        }
    }

    func forceUpdateRuleFileFromBundleFile() {
        updateRuleFileFromBundleFile()
    }


    func updateRuleFileFromImportedFile(_ path: String) {
        saveToRuleFile(fromURLString: path)
        let defaults = UserDefaults.init(suiteName: groupName)
        defaults?.set(userImportFileSource, forKey: currentFileSource)
        defaults?.synchronize()
    }


    func readCurrentRuleFileContent() -> String {
        //if default, return file in bundle. if custom, return file in downlaod position
        var content = ""

        if getCurrentFileSource() == defaultFileSource {
            if let path = Bundle.main.path(forResource: "rule", ofType: "config") {
                do {
                    content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                } catch {
                    DDLogError("\(error)")
                }
            }
        } else {
            let customPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/" + configFileName
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: customPath) {
                do {
                    content = try String(contentsOfFile: customPath, encoding: String.Encoding.utf8)
                } catch {
                    DDLogError("\(error)")
                }
            }
        }
        return content
    }

    func saveToCustomRuleFile(withContent content: String) {
        let customPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/" + configFileName
        let fileManager = FileManager.default

        fileManager.createFile(atPath: customPath, contents: nil, attributes: nil)

        do {
            let filehandle = try FileHandle(forWritingTo: URL(fileURLWithPath: customPath))
            filehandle.write(content.data(using: String.Encoding.utf8)!)
            filehandle.synchronizeFile()
            filehandle.closeFile()
        } catch {
            DDLogError("\(error)")
            return
        }

        saveToRuleFile(withContent: content)

        let defaults = UserDefaults.init(suiteName: groupName)
        defaults?.set(userImportFileSource, forKey: currentFileSource)
        defaults?.synchronize()

    }

    private func getCurrentFileSource() -> String {
        let defaults = UserDefaults(suiteName: groupName)
        var source = ""

        if let fileSource = defaults?.value(forKey: currentFileSource) as? String {
            source = fileSource
        } else {
            source = defaultFileSource
            defaults?.set(defaultFileSource, forKey: currentFileSource)
            defaults?.synchronize()
        }
        return source
    }

    private func isBundleRuleFileNewer() -> Bool {
        let defaults = UserDefaults.init(suiteName: groupName)
        var bundleRuleFileNewer = false

        if let savedRuleFileVersion = defaults?.value(forKey: savedFileVersion) as? Int {
            if bundlefileVersion > savedRuleFileVersion {
                bundleRuleFileNewer = true
            }
        } else {
            bundleRuleFileNewer = true
        }
        return bundleRuleFileNewer
    }

    private func updateRuleFileFromBundleFile() {
        if let path = Bundle.main.path(forResource: "rule", ofType: "config") {
            saveToRuleFile(fromURLString: path)
            let defaults = UserDefaults.init(suiteName: groupName)
            defaults?.set(bundlefileVersion, forKey: savedFileVersion)
            defaults?.set(defaultFileSource, forKey: currentFileSource)
            defaults?.synchronize()
        }
    }

    private func saveToRuleFile(fromURLString urlString: String) {
        do {
            let fileString = try String(contentsOfFile: urlString, encoding: String.Encoding.utf8)
            saveToRuleFile(withContent: fileString)
        } catch {
            DDLogError("\(error))")
        }
    }

    private func saveToRuleFile(withContent content: String) {
        let fileManager = FileManager.default
        var returnKey = "\r\n"

        if !content.contains(returnKey) {
            returnKey = "\n"
        }

        let items = content.components(separatedBy: returnKey)
        var currentClass = ""
        var ruleItems = [String]()
        var rewriteItems = [String]()

        for item in items {
            if item.hasPrefix("[") {
                if item == "[Rule]" {
                    currentClass = "Rule"
                } else if item == "[URL Rewrite]" {
                    currentClass = "URL Rewrite"
                } else {
                    currentClass = ""
                }
                continue
            }

            if item.hasPrefix("#") || item == "" {
                continue
            }

            switch currentClass {
            case "Rule":
                ruleItems.append(item)
            case "URL Rewrite":
                rewriteItems.append(item)
            default:
                break
            }
        }

        guard let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return
        }

        // rule
        let ruleURL = url.appendingPathComponent(ruleFileName)
        fileManager.createFile(atPath: ruleURL.path, contents: nil, attributes: nil)
        do {
            let filehandle = try FileHandle(forWritingTo: ruleURL)
            for item in ruleItems {
                filehandle.seekToEndOfFile()
                filehandle.write("\(item)\n".data(using: String.Encoding.utf8)!)
            }
            filehandle.synchronizeFile()
            filehandle.closeFile()
        } catch {
            DDLogError("\(error)")
            return
        }

        //rewrite
        let rewriteURL = url.appendingPathComponent(rewriteFileName)
        fileManager.createFile(atPath: rewriteURL.path, contents: nil, attributes: nil)
        do {
            let filehandle = try FileHandle(forWritingTo: rewriteURL)
            for item in rewriteItems {
                filehandle.seekToEndOfFile()
                filehandle.write("\(item)\n".data(using: String.Encoding.utf8)!)
            }
            filehandle.synchronizeFile()
            filehandle.closeFile()
        } catch {
            DDLogError("\(error)")
            return
        }
    }

}
