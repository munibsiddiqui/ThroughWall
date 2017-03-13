//
//  Rule.swift
//  ThroughWall
//
//  Created by Bin on 30/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import CocoaLumberjack

enum DomainRule: CustomStringConvertible {
    case Proxy
    case Direct
    case Reject
    case Unkown
    
    var description: String {
        switch self {
        case .Proxy:
            return "Proxy"
        case .Direct:
            return "Direct"
        case .Reject:
            return "Reject"
        default:
            return "Unknow"
        }
    }
}

class Rule {
    
    static let sharedInstance = Rule()
    
    private var fullRules: [String: DomainRule]?
    private var suffixRules: [String: DomainRule]?
    private var containRules: [String: DomainRule]?
    private var ipRules: [String: DomainRule]?
    private var blockAD = false
    private var globalMode = false
    
    private func trasnlateRule(fromString value: String) -> DomainRule {
        switch value.lowercased() {
        case "proxy":
            return DomainRule.Proxy
        case "direct":
            return DomainRule.Direct
        case "reject":
            return DomainRule.Reject
        default:
            return DomainRule.Unkown
        }
    }
    
    func itemsInRuleFile() -> [String] {
        let fileManager = FileManager.default
        guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
            return []
        }
        url.appendPathComponent(ruleFileName)
        
        var fileString = ""
        do {
            fileString = try String(contentsOf: url, encoding: String.Encoding.utf8)
        }catch{
            DDLogDebug("\(error)")
            return []
        }
        
        var items = fileString.components(separatedBy: "\n")
        items.removeLast()
        return items
    }
    
    private func translateToBinary(fromIP ip: String) -> String {
        var ipParts = ip.components(separatedBy: ".")
        for (index, ipPart) in ipParts.enumerated() {
            ipParts[index] = pad(String(Int(ipPart) ?? 0, radix: 2), toSize: 8)
        }
        return ipParts.joined()
    }
    
    private func translateToBinary(fromIPRange ip: String) -> String {
        let parts = ip.components(separatedBy: "/")
        let ipAddress = translateToBinary(fromIP: parts[0])
        
        if parts.count > 1 {
            let index = ipAddress.index(ipAddress.startIndex, offsetBy: Int(parts[1])!)
            return ipAddress.substring(to: index)
        }
        return ipAddress
    }
    
    private func pad(_ string : String, toSize: Int) -> String {
        var padded = string
        for _ in 0..<toSize - string.characters.count {
            padded = "0" + padded
        }
        return padded
    }
    
    func analyzeRuleFile() {
        
        let items = itemsInRuleFile()
        
        fullRules = [String: DomainRule]()
        suffixRules = [String: DomainRule]()
        containRules = [String: DomainRule]()
        ipRules = [String: DomainRule]()
        
        for item in items {
//            DDLogVerbose(item)
            let components = item.components(separatedBy: ",")
            if components.count >= 3 {
                let rule = trasnlateRule(fromString: components[2])
                
                switch components[0] {
                case "DOMAIN":
                    fullRules?[components[1]] = rule
                case "DOMAIN-SUFFIX":
                    suffixRules?[components[1]] = rule
                case "DOMAIN-MATCH":
                    fallthrough
                case "DOMAIN-KEYWORD":
                    containRules?[components[1]] = rule
                case "IP-CIDR":
                    ipRules?[translateToBinary(fromIPRange: components[1])] = rule
                default:
                    break
                }
            }
        }
        
        let defaults = UserDefaults.init(suiteName: groupName)
        
        if let block = defaults?.value(forKey: blockADSetting) as? Bool{
            blockAD = block
//            DDLogVerbose("Block AD \(blockAD)")
        }
        if let global = defaults?.value(forKey: globalModeSetting) as? Bool {
            globalMode = global
//            DDLogVerbose("Global Mode \(globalMode)")
        }
        
//        if let realFullRules = fullRules {
//            DDLogVerbose("fullRule")
//            for fullRule in realFullRules {
//                DDLogVerbose("\(fullRule.key) : \(fullRule.value.description)")
//            }
//        }
//        if let realSuffixRules = suffixRules {
//            DDLogVerbose("suffixRule")
//            for suffixRule in realSuffixRules {
//                DDLogVerbose("\(suffixRule.key) : \(suffixRule.value.description)")
//            }
//        }
//        
//        if let realContainRules = containRules {
//            DDLogVerbose("containRule")
//            for containRule in realContainRules {
//                DDLogVerbose("\(containRule.key) : \(containRule.value.description)")
//            }
//        }
    }
    
    private func validateIpAddress(ipToValidate: String) -> Bool {
        
        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
            // IPv6 peer.
            return false
        }
        else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
            // IPv4 peer.
            return true
        }
        
        return false;
    }
    
    private func _ruleForDomain(_ domain: String) -> DomainRule {
        
        if validateIpAddress(ipToValidate: domain) {
            let ipInBinary = translateToBinary(fromIP: domain)
            if let realIPRules = ipRules {
                for ipRule in realIPRules {
                    if ipInBinary.hasPrefix(ipRule.key) {
                        return ipRule.value
                    }
                }
            }
        }else {
            if let rule = fullRules?[domain] {
                return rule
            }
            
            if let realSuffixRules = suffixRules {
                for suffixRule in realSuffixRules {
                    if domain.hasSuffix(suffixRule.key) {
                        return suffixRule.value
                    }
                }
            }
            
            if let realContainRules = containRules {
                for containRule in realContainRules {
                    if domain.contains(containRule.key){
                        return containRule.value
                    }
                }
            }
        }
        return DomainRule.Direct
    }
    
    func ruleForDomain(_ domain: String) -> DomainRule {
        var rule = _ruleForDomain(domain)
        switch rule {
        case .Direct:
            if globalMode {
                rule = .Proxy
            }
        case .Reject:
            if !blockAD && globalMode {
                rule = .Direct
            }
        default:
            break
        }
        return rule
    }
}
