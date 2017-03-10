//
//  Common.swift
//  ThroughWall
//
//  Created by Bin on 30/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import Foundation

let kChoosenRuleImportMethod = "Bingo.ThroughWall.ChoosenRuleImportMethod"
let kRuleImportMethodValue = "Bingo.ThroughWall.RuleImportMethodValue"
let kTapLocationInRuleView = "Bingo.ThroughWall.TapLocationInRuleView"
let kQRCodeExtracted = "Bingo.ThroughWall.QRCodeExtracted"

let configFileName = "rule.config"
let kTunnelProviderBundle = "Bingo.ThroughWall.TWPacketTunnelProvider"
let kDeleteEditingVPN = "Bingo.ThroughWall.DeleteEditingVPN"
let kConfigureVersion = "Bingo.TW.ConfigureVersion"
let currentConfigureVersion = 1

let databaseFolderName = "DataBase"
let databaseFileName = "Record.sqlite"

let groupName = "group.Bingo.ThroughWall"
let ruleFileName = "rule.conf"
let siteFileName = "site.conf"
let PacketTunnelProviderLogFolderName = "PacketTunnelProvider"
let bundlefileVersion = 0
let savedFileVersion = "Bingo.SavedFileVersion"
let currentFileSource = "Bingo.FileSource"
let defaultFileSource = "Bingo.FileSource.Default"
let userImportFileSource = "Bingo.FileSource.UserImport"

let blockADSetting = "Bingo.blockADSetting"
let globalModeSetting = "Bingo.globalModeSetting"

let downloadCountKey = "count.download"
let uploadCountKey = "count.upload"
let proxyDownloadCountKey = "count.proxyDownload"
let proxyUploadCountKey = "count.proxyUpload"
let adjustCountKey = "count.adjust"
let recordingDateKey = "Bingo.recordingDate"

let saveContextNotification = "Bingo.TWPacketTunnelProvider.saveContext"

let shouldParseTrafficKey = "Bingo.ShouldParseTraffic"
let logLevelKey = "Bingo.LogLevel"

enum DarwinNotifications: String {
    case updateWidget = "updataWidget"
}
