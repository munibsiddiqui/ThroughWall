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
let kNewRuleValueUpdate = "Bingo.ThroughWall.NewRuleValueUpdate"
let kRuleSaved = "Bingo.ThroughWall.RuleSaved"
let kRuleDeleted = "Bingo.ThroughWall.RuleDeleted"

let configFileName = "rule.config"
let kTunnelProviderBundle = "Bingo.ThroughWall.TWPacketTunnelProvider"
let kDeleteEditingVPN = "Bingo.ThroughWall.DeleteEditingVPN"
let kSaveVPN = "Bingo.ThroughWall.SaveVPN"
let kConfigureVersion = "Bingo.TW.ConfigureVersion"
let currentConfigureVersion = 1
let kSelectedServerIndex = "Bingo.TW.SelectedServerIndex"

let kCurrentManagerStatus = "Bingo.TW.ManagerStatus"
let kHintVersion = "Bingo.HintVersion"
let hintVersion = 1

let databaseFolderName = "DataBase"
let databaseFileName = "Record.sqlite"
let parseFolderName = "Parse"

let groupName = "group.Bingo.ThroughWall"
let ruleFileName = "rule.conf"
let generalFileName = "gene.conf"
let rewriteFileName = "rew.conf"
let siteFileName = "site.conf"
let PacketTunnelProviderLogFolderName = "PacketTunnelProvider"
let bundlefileVersion = 6
let savedFileVersion = "Bingo.SavedFileVersion"
let currentFileSource = "Bingo.FileSource"
let defaultFileSource = "Bingo.FileSource.Default"
let userImportFileSource = "Bingo.FileSource.UserImport"

let klogLevel = "Bingo.LogLevel"
let logLevels = ["off","error","warning","info","debug","verbose","all"]

let blockADSetting = "Bingo.blockADSetting"
let globalModeSetting = "Bingo.globalModeSetting"

let downloadCountKey = "count.download"
let uploadCountKey = "count.upload"
let proxyDownloadCountKey = "count.proxyDownload"
let proxyUploadCountKey = "count.proxyUpload"
let adjustCountKey = "count.adjust"
let recordingDateKey = "Bingo.recordingDate"
let currentTime = "Bingo.currentTime"

let saveContextNotification = "Bingo.TWPacketTunnelProvider.saveContext"

let shouldParseTrafficKey = "Bingo.ShouldParseTraffic"
let logLevelKey = "Bingo.LogLevel"


let HTTPRequestHead = 0
let HTTPSRequestHead = 1
let HTTPResponseHead = 2
let HTTPSResponseHead = 3

let ResponseBodyType = 0
let RequestBodyType = 1

enum DarwinNotifications: String {
    case updateWidget = "updataWidget"
}
