//
//  ViewController.swift
//  ChiselLogViewer
//
//  Created by Bingo on 09/07/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    var coreDataController: CoreDataController?
    var hostTraffics = [HostTraffic]()
    let localFormatter = DateFormatter()
    var databaseURL: URL!

    @IBOutlet weak var tableView: NSTableView!

    let columnItems = ["No.", "Tag", "Rule", "Host", "Request Time", "Response Time", "Disconnect Time", "Up", "Down", "Status", "Request Head", "Response Head", "Request Body", "Response Body"]


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        localFormatter.locale = Locale.current
        localFormatter.dateFormat = "HH:mm:ss:SSS"

        let securityTest = SecurityTest()
        securityTest.start()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    @objc func doubleClicked(_ sender: AnyObject) {
        if let tableView = sender as? NSTableView {
            print("row \(tableView.selectedRow)")
        }
    }

    @IBAction func openDocument(_ sender: AnyObject) {
        let dialog = NSOpenPanel();

//        dialog.title = "Choose a .txt file";
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canChooseDirectories = true;
        dialog.canCreateDirectories = true;
        dialog.allowsMultipleSelection = false;
//        dialog.allowedFileTypes = ["txt"];

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file

            if let _result = result {
                databaseURL = _result
                coreDataController = CoreDataController(withBaseURL: _result)
                loadRequestLog()
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }

    @IBAction func tableClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        let column = sender.clickedColumn

        if column == 11 || column == 10 {
            let viewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "headViewController")) as! HeadContentViewController

            if column == 10 {
                if let head = hostTraffics[row].requestHead?.head {
                    viewController.content = head
                }
            } else {
                if let head = hostTraffics[row].responseHead?.head {
                    viewController.content = head
                }
            }

            let popOver = NSPopover()
            popOver.contentViewController = viewController
            popOver.animates = true
            popOver.behavior = .transient
            let rowRect = tableView.rect(ofRow: row)
            let columnRect = tableView.rect(ofColumn: column)
            let rect = NSRect(x: columnRect.minX, y: rowRect.minY, width: columnRect.width, height: rowRect.height)

            popOver.show(relativeTo: rect, of: tableView, preferredEdge: .minX)
        } else if column == 13 || column == 12 {
            let viewController = storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "bodyViewController")) as! BodyContentViewController
            viewController.hostTraffic = hostTraffics[row]
            viewController.parseURL = databaseURL.appendingPathComponent("Parse")
            if column == 12 {
                viewController.isRequestBody = true
            } else {
                viewController.isRequestBody = false
            }
            presentViewControllerAsSheet(viewController)
        }
    }

    func loadRequestLog() {
        guard let coreDataCtl = coreDataController else {
            print("nil controller")
            return
        }
        let fetch: NSFetchRequest<HostTraffic> = HostTraffic.fetchRequest()
        fetch.includesPropertyValues = false
        fetch.includesSubentities = false
        do {
            var hostTraffics = try coreDataCtl.getContext().fetch(fetch)
            hostTraffics.sort(by: { (first, second) -> Bool in
                guard let firstTime = first.hostConnectInfo?.requestTime, let secondTime = second.hostConnectInfo?.requestTime else {
                    return true
                }
                if firstTime.timeIntervalSince(secondTime as Date) > 0 {
                    return false
                }
                return true
            })
            self.hostTraffics = hostTraffics
            resertTableFrame()
            tableView.reloadData()

            let descriptorReqTime = NSSortDescriptor(key: "Request Time", ascending: true)
            let descriptorHost = NSSortDescriptor(key: "Host", ascending: true)

            tableView.tableColumns[3].sortDescriptorPrototype = descriptorHost
            tableView.tableColumns[4].sortDescriptorPrototype = descriptorReqTime

        } catch {
            print(error)
        }
    }

    func resertTableFrame() {
        for column in tableView.tableColumns {
            tableView.removeTableColumn(column)
        }
        for columnItem in columnItems {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "textColumn"))
            column.title = columnItem
            tableView.addTableColumn(column)
        }
    }
}


extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return hostTraffics.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "textCell"), owner: nil) as? NSTableCellView else {
            return nil
        }
        cell.textField?.stringValue = ""

        let hostTraffic = hostTraffics[row]
        switch tableColumn!.title {
        case "No.":
            cell.textField?.stringValue = "\(row)"
        case "Tag":
            if let tag = hostTraffic.hostConnectInfo?.tag {
                cell.textField?.stringValue = "\(tag)"
            }
        case "Rule":
            if let rule = hostTraffic.hostConnectInfo?.rule {
                cell.textField?.attributedStringValue = getAttributtedRule(withRule: rule)
            }
        case "Host":
            if let host = hostTraffic.hostConnectInfo?.name {
                if let port = hostTraffic.hostConnectInfo?.port {
                    cell.textField?.stringValue = "\(host):\(port)"
                }
            }
        case "Request Time":
            if let reqTime = hostTraffic.hostConnectInfo?.requestTime {
                cell.textField?.stringValue = localFormatter.string(from: reqTime)
            }
        case "Response Time":
            if let resTime = hostTraffic.responseHead?.time {
                cell.textField?.stringValue = localFormatter.string(from: resTime)
            }
        case "Disconnect Time":
            if let disTime = hostTraffic.disconnectTime {
                cell.textField?.stringValue = localFormatter.string(from: disTime)
            }
        case "Up":
            cell.textField?.stringValue = "\(hostTraffic.outCount)"
        case "Down":
            cell.textField?.stringValue = "\(hostTraffic.inCount)"
        case "Status":
            if hostTraffic.forceDisconnect {
                cell.textField?.attributedStringValue = NSAttributedString(string: "ForceDisconnect", attributes: [NSAttributedStringKey.backgroundColor: NSColor.gray])
            } else {
                if hostTraffic.inProcessing {
                    cell.textField?.attributedStringValue = NSAttributedString(string: "Incomplete", attributes: [NSAttributedStringKey.backgroundColor: NSColor.red])
                } else {
                    cell.textField?.attributedStringValue = NSAttributedString(string: "Complete", attributes: [NSAttributedStringKey.backgroundColor: NSColor(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
                }
            }
        case "Request Head":
            if let reqHead = hostTraffic.requestHead?.head {
                let temp = reqHead.components(separatedBy: "\r\n")
                cell.textField?.stringValue = temp.joined(separator: " ")
            }
        case "Response Head":
            if let resHead = hostTraffic.responseHead?.head {
                let temp = resHead.components(separatedBy: "\r\n")
                cell.textField?.stringValue = temp.joined(separator: " ")
            }
        case "Request Body":
            if let _ = hostTraffic.requestWholeBody?.fileName {
                cell.textField?.stringValue = "click to view"
            }
        case "Response Body":
            if let _ = hostTraffic.responseWholeBody?.fileName {
                cell.textField?.stringValue = "click to view"
            }
        default:
            break
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        if let key = sortDescriptor.key {
            let ascending = sortDescriptor.ascending
            switch key {
            case "Request Time":
                hostTraffics.sort(by: { (first, second) -> Bool in
                    guard let fReqTime = first.hostConnectInfo?.requestTime else {
                        return ascending
                    }
                    guard let sReqTime = second.hostConnectInfo?.requestTime else {
                        return !ascending
                    }
                    if fReqTime.timeIntervalSince(sReqTime) <= 0 {
                        return ascending
                    }
                    return !ascending
                })
                break
            case "Host":
                hostTraffics.sort(by: { (first, second) -> Bool in
                    guard let fName = first.hostConnectInfo?.name else {
                        return ascending
                    }
                    guard let sName = second.hostConnectInfo?.name else {
                        return !ascending
                    }
                    if fName.compare(sName).rawValue <= 0 {
                        return ascending
                    }
                    return !ascending
                })
            default:
                break
            }
        }
        tableView.reloadData()
    }


    func getAttributtedRule(withRule rule: String) -> NSAttributedString {
        switch rule.lowercased() {
        case "direct":
            let attributeRule = NSAttributedString(string: rule, attributes: [NSAttributedStringKey.backgroundColor: NSColor(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
            return attributeRule
        case "proxy":
            let attributeRule = NSAttributedString(string: rule, attributes: [NSAttributedStringKey.backgroundColor: NSColor.orange])
            return attributeRule
        default:
            let attributeRule = NSAttributedString(string: rule, attributes: [NSAttributedStringKey.backgroundColor: NSColor.red])
            return attributeRule
        }
    }
}


class SecurityTest {
    let encrypt = encryptAPI()
    let encrypt_server = encryptAPI()
    var read_ctx = encryption_ctx()
    var read_ctx_server = encryption_ctx()
    
    func start() {

        let password = "19880816"
        let method = "aes-256-cfb"
        
        encrypt.configEncryption(withPawwsord: password, method: method)
        encrypt_server.configEncryption(withPawwsord: password, method: method)
        encrypt.initEncryption(&read_ctx)
        encrypt_server.initEncryption(&read_ctx_server)
        
        print(read_ctx)
        
        var rawData = Array<UInt8>(arrayLiteral: 0x53, 0xbe, 0x5c, 0xe0, 0x7c, 0xdd, 0x40, 0x95, 0x4f, 0xe3, 0xbf, 0x56, 0xec, 0xd2, 0xf4, 0xc6, 0x65, 0xe6, 0x88, 0x33, 0x76, 0x29, 0xbe, 0x1b, 0xba, 0x27, 0x0c, 0x8b, 0x89, 0xd1, 0xf4, 0x4f, 0xe8, 0x64)
        
        decryptData(rawData: rawData)
        
        rawData = Array<UInt8>(arrayLiteral: 0xf1, 0xb4, 0x19, 0x3a, 0xbd, 0xf4, 0xfb, 0x05, 0xf9, 0x05, 0x18, 0xc1, 0x59, 0x33, 0x52, 0x23, 0x77, 0xf3, 0x92, 0xfe, 0x59, 0xa6, 0xb0, 0xb3, 0xc9, 0xec, 0x8b, 0xdf, 0xeb, 0x21, 0xe6, 0xbf, 0xb3, 0x97, 0x68, 0xe7, 0x3b, 0x7d, 0x8b, 0x95, 0xa0, 0x18, 0x1b, 0x57, 0xe7, 0x6e, 0xc5, 0x32, 0x45, 0x59, 0x3f, 0xda, 0x84, 0x1e, 0x83, 0x8a, 0x92, 0xe2, 0x7b, 0x2c, 0x67, 0x0a, 0x44, 0xa6, 0x4d, 0x9e, 0xe5, 0xea, 0xd6, 0x73, 0x5a, 0x22, 0x19, 0xe3, 0x90, 0x65, 0xc0, 0xb3, 0x58, 0xfb, 0xda, 0x63, 0xe4, 0x4d, 0x52, 0xdb, 0xc8, 0xd4, 0x71, 0x07, 0xa4, 0x3f, 0x52, 0xa5, 0x8e, 0x12, 0x93, 0xe1, 0x6f, 0x58, 0x4c, 0x09, 0x10, 0xe3, 0x30, 0xc9, 0x5a, 0x9b, 0xfc, 0x41, 0x9f, 0x06, 0xcb, 0x3c, 0x93, 0xde, 0x65, 0x69, 0x1f, 0x10, 0x5e, 0x0a, 0x02, 0x54, 0x40, 0x7e, 0x40, 0x5a, 0x07, 0xf7, 0xd0, 0xd1, 0x80, 0xcd, 0x42, 0x3e, 0xf1, 0x17, 0x84, 0x2a, 0x4b, 0xad, 0x13, 0x8e, 0x50, 0x5c, 0xd7, 0xf1, 0xfe, 0xad, 0x9e, 0x77, 0xd5, 0x63, 0xe0, 0x07, 0xfd, 0x8e, 0x31, 0x62, 0x2a, 0x19, 0x01, 0xcd, 0x56, 0x91, 0x39, 0xbd, 0x00, 0x0d, 0x38, 0x8e, 0x63, 0x3a, 0x12, 0xdb, 0x11, 0x0e, 0xe1, 0x55, 0x17, 0xdb, 0xe2, 0x43, 0x6b, 0xd8, 0x24, 0xe0, 0x80, 0xf6, 0x8c, 0x5d, 0x84, 0x70, 0xaa, 0x58, 0x29, 0xf1, 0xf7, 0x45, 0x04, 0x33, 0x72, 0x67, 0x85, 0x66, 0x02, 0xcd, 0xc5, 0x15, 0x36, 0xb1, 0x4b, 0xf6, 0x0e, 0x50, 0x1d, 0x0b, 0x2e, 0x99, 0x93, 0x77, 0x9a, 0x0c, 0xe7, 0x4b, 0x7a, 0x4b, 0x24, 0x14, 0x65, 0x33, 0xff, 0x63, 0xd4, 0xa1, 0x62, 0xd5, 0x3c, 0x5b, 0x3d, 0x6e, 0xe0, 0x68, 0x84, 0xc0, 0x3d, 0x78, 0x82, 0x38, 0x46, 0xfb, 0x0a, 0xd7, 0x50, 0x61, 0xc7, 0x30, 0xde, 0x6a, 0xa0, 0xc1, 0x1f, 0xcb, 0xab, 0xd8, 0x00, 0x0e, 0x85, 0x8c, 0x15, 0xb2, 0x4b, 0xab, 0x1d, 0xdc, 0x1c, 0x67, 0xed, 0x06, 0x9d, 0x43, 0x77, 0x40, 0x8a, 0xab, 0xbf, 0x03, 0x0a, 0x5e, 0x4f, 0xa9, 0x4d, 0x19, 0x3a, 0xf6, 0x8c, 0x75, 0xba, 0x24, 0x52, 0x6b, 0xe2, 0x27, 0xdb, 0x71, 0x4e, 0xb7, 0x47, 0xd0, 0xc2, 0xa7, 0x65, 0xc1, 0x35, 0x66, 0x7a, 0x4a, 0x5d, 0xa2, 0xd8, 0x36, 0x84, 0xc9, 0x66, 0xc8, 0xb7, 0x3a, 0x46, 0x1d, 0xbc, 0xbf, 0x3f, 0xf2, 0x9e, 0x1b, 0x1e, 0xac, 0x0d, 0x35, 0xe1, 0x78, 0xba, 0xa9, 0x0c, 0xe2, 0x30, 0x6a, 0x1e, 0x7d, 0x36, 0x51, 0x6b, 0x20, 0x96, 0xde, 0x05, 0xa3, 0x1d, 0x1b, 0xdf, 0x69, 0x73, 0x54, 0xea, 0x0a, 0x8c, 0x02, 0x0f, 0xc6, 0x67, 0x8a, 0x2e, 0xa7, 0xeb, 0x06, 0xf4, 0x65, 0x9c, 0x10, 0x97, 0x6f, 0xbf, 0x86, 0x03, 0x9c, 0xb8, 0x57, 0x19, 0xc0, 0x03, 0x14, 0x25, 0x53, 0xfb, 0xb0, 0x88, 0x02, 0x2b, 0x8d, 0x30, 0xce, 0xee, 0x41, 0x7f, 0xca, 0xa7, 0x05, 0x04, 0xc5, 0xf1, 0x7a, 0xc8, 0xb5, 0xd2, 0x13, 0x99, 0xdf, 0x92, 0xcc, 0x9f, 0xbb, 0x1c, 0x18, 0x10, 0xfb, 0xfb, 0x8c, 0x7d, 0x99, 0xce, 0x88, 0x8f, 0xa5, 0xac, 0xec, 0x5d, 0x7c, 0xcc, 0xda, 0xd5, 0x4c, 0xd3, 0xec, 0x4d, 0x95, 0xf9, 0x8a, 0x76, 0xbd, 0x35, 0x45, 0xa3, 0x0c, 0xa8, 0x0a, 0xd2, 0xfa, 0xfd, 0xc6, 0x44, 0x20, 0xb9, 0xa2, 0x7e, 0x44, 0x84, 0xaf, 0x82, 0xf1, 0x5f, 0xaa, 0x7e, 0x84, 0x7c, 0x6c, 0x65, 0xd4, 0xcc, 0x2f, 0x7f, 0xdf, 0xc0, 0x75, 0x9d, 0xec, 0x28, 0xd4, 0xaa, 0x99, 0x7f, 0x65, 0x09, 0xbe, 0xb2, 0x99, 0xbc, 0x4b, 0x4e, 0x0c, 0xb9, 0x3d, 0x8f, 0x9d, 0x5a, 0x70, 0x7b, 0x5e, 0x17, 0xef, 0xd7, 0xc0, 0xbc, 0x29, 0xda, 0xb0, 0xe2)
        
        decryptData(rawData: rawData)
        
        rawData = Array<UInt8>(arrayLiteral: 0x4f, 0x40, 0xf3, 0x15, 0xd5, 0x3e, 0xae, 0xbe, 0xfe, 0x03, 0x79, 0x97, 0xfe, 0xcc, 0x85, 0xb5, 0x71, 0xa2, 0x92, 0xab, 0xe2, 0x09, 0xbe, 0xc0, 0x1d, 0x21, 0xa5, 0xee, 0xab, 0x42, 0x26, 0x14, 0x04, 0x55, 0x89, 0x41, 0xf0, 0x1c, 0xbe, 0x8d, 0xb4, 0xa3, 0xe5, 0x4e, 0xb4, 0x13, 0x53, 0xfd, 0x08, 0xdd, 0x11, 0xcb, 0x7b, 0xf0, 0xa1, 0x64, 0xbc, 0x8e, 0x34, 0x3a, 0x85, 0xa3, 0x88, 0x9a, 0x3e, 0x04, 0x24, 0x12, 0x96, 0x7f, 0x33, 0x74, 0x47, 0x4e, 0x2d, 0x93, 0xff, 0x1e, 0x06, 0x84, 0x96, 0xc0, 0xb7, 0xe0, 0xb2, 0x4c, 0x5d, 0x84, 0x1a, 0x89, 0xa0, 0x8e, 0x7d, 0x33, 0xeb, 0x47, 0xb5, 0xf4, 0xf9, 0x54, 0x16, 0xdd, 0x37, 0x47, 0x30, 0x73, 0xda, 0x12, 0xd6, 0xf3, 0x7b, 0x8f, 0x57, 0x65, 0xe5, 0x8d, 0x77, 0xdd, 0x44, 0x37, 0x62, 0xe9, 0x28, 0xa5, 0x79, 0xbd, 0xf4, 0xab, 0x2d, 0x1a, 0xa9, 0xc1, 0xd3, 0x20, 0x33, 0x66, 0xb5, 0xb1, 0xa6, 0x9d, 0xc4, 0x8f, 0xef, 0x17, 0x92, 0x84, 0xab, 0x71, 0xc7, 0x15, 0x85, 0x74, 0xcf, 0xb8, 0xe7, 0xa1, 0x65, 0x15, 0xce, 0x9c, 0x4f, 0xcd, 0xe4, 0xef, 0x5e, 0x3c, 0xcd, 0x94, 0x8b, 0xce, 0x47, 0xfd, 0x42, 0xab, 0xc7, 0x01, 0x8f, 0x74, 0x15, 0x64, 0x2e, 0x68, 0xea, 0x24, 0x58, 0xaa, 0x50, 0x78, 0x1d, 0x87, 0x40, 0x4f, 0x64, 0x0e, 0x5b, 0x9d, 0x96, 0xa1, 0x24, 0xa3, 0x34, 0xa3, 0xd0, 0x05, 0xe9, 0x97, 0xd5, 0xc7, 0x86, 0xf1, 0xc7, 0x5c, 0x1a, 0x16, 0xf0, 0xfc, 0x22, 0xdb, 0xc2, 0x71, 0xd4, 0x01, 0x3e, 0x57, 0x00, 0xc0, 0x89, 0x77, 0x11, 0x25, 0x9b, 0xc9, 0x91, 0x14, 0x33, 0x9d, 0x67, 0x0d, 0x1c, 0x72, 0xaa, 0x2d, 0x57, 0x91, 0xde, 0x04, 0xfe, 0x94, 0x4d, 0x51, 0x16, 0x1b, 0x08, 0xaa, 0xb6, 0x71, 0x93, 0xcd, 0x2b, 0xc0, 0xe0, 0xb2, 0x96, 0xa2, 0x49, 0x4a, 0x72, 0xbb, 0xbf, 0xfc, 0x3e, 0x50, 0xef, 0x57, 0xc2, 0x46, 0x4e, 0xb0, 0x25, 0xa7, 0x2a, 0x77, 0x26, 0x61, 0xd5, 0x24, 0xb3, 0xf6, 0x1d, 0x8d, 0xca, 0xff, 0xed, 0x03, 0xf3, 0x53, 0xb9, 0x51, 0x80, 0x11, 0xd7, 0x23, 0xb6, 0x66, 0x5d, 0x30, 0x06, 0x50, 0x66, 0xaf, 0xe4, 0x74, 0x0a, 0x76, 0x1f, 0x23, 0xd5, 0xdf, 0x32, 0x26, 0xb0, 0x46, 0x06, 0xfa, 0x52, 0xd0, 0x74, 0xf3, 0x4f, 0x90, 0xd3, 0xb0, 0x29, 0x36, 0xd8, 0x41, 0x54, 0x7d, 0x6d, 0xf7, 0x5b, 0x92, 0x09, 0x7f, 0x2e, 0x32, 0x15, 0xda, 0xcd, 0xbd, 0x0b, 0x39, 0xa8, 0x55, 0x67, 0x34, 0xad, 0xce, 0x0d, 0x85, 0x66, 0xc3, 0x5a, 0x36, 0x0a, 0x14, 0x68, 0xfb, 0x13, 0x8e, 0x4f, 0xfc, 0x27, 0x06, 0xae, 0x93, 0x23, 0x3a, 0x46, 0x3d, 0xb6, 0xbd, 0x92, 0x7e, 0xd5, 0xe2, 0xad, 0x2f, 0x8c, 0x81, 0x12, 0xf2, 0xed, 0x33, 0xb9, 0xe3, 0x7d, 0x26, 0xed, 0xf6, 0xb1, 0x40, 0x50, 0x3a, 0xd4, 0xdd, 0xf3, 0x4d, 0xa8, 0xa5, 0x69, 0xd6, 0x67, 0x77, 0x64, 0x8e, 0x6c, 0x88, 0x9d, 0x16, 0x22, 0x16, 0x7d, 0xd1, 0x40, 0xcc, 0x81, 0x95, 0x66, 0xef, 0x66, 0x35, 0xe7, 0x0f, 0x65, 0xa0, 0xe1, 0x0e, 0xe7, 0xfd, 0xaf, 0xb7, 0xdf, 0x5c, 0xc7, 0xaa, 0x04, 0xf8, 0x2a, 0x18, 0x4e, 0xc0, 0x5f, 0x7e, 0xbe, 0xf3, 0x44, 0xcc, 0x32, 0x4f, 0x32, 0x9d, 0xd5, 0x1e, 0xe4, 0x00, 0xb3, 0x0e, 0xdc, 0x8e, 0x47, 0x3c, 0xe9, 0x99, 0x9a, 0xc1, 0xfa, 0x4b, 0xc4, 0x1e, 0xbc, 0x01, 0x4a, 0x1d, 0x18, 0x4a, 0x51, 0x87, 0xef, 0xe0, 0x43, 0xf7, 0x7c, 0x82, 0xd7, 0x2d, 0xd4, 0xe9, 0x31, 0x1f, 0x2b, 0x1b, 0x9c, 0x9d, 0x1f, 0x75, 0x31, 0xc4, 0x2b, 0x4c, 0x00, 0x87, 0x47, 0x0e, 0x2a, 0xc3, 0x8e, 0xcc, 0xa3, 0x3b, 0x26, 0x0e, 0x4c, 0x83, 0x12, 0xfe, 0xe9, 0xc3, 0x48, 0xac, 0xf5, 0x00, 0xdb, 0xb7, 0x9f, 0xc4, 0xee, 0x5e, 0x10, 0xce, 0x16, 0x17, 0x60, 0x14, 0x00, 0xc1, 0xf4, 0xc3, 0x35, 0x2d, 0xf1, 0x48, 0x57, 0x32, 0x95, 0xd7, 0xa5, 0x9d, 0xf9, 0x3e, 0x3f, 0x57, 0xa1, 0x71, 0x7b, 0x01, 0x7e, 0xf4, 0x18, 0x79, 0x37, 0x3a, 0x30, 0x8f, 0x6b, 0x66, 0xe1, 0xba, 0xd2, 0x3f, 0xd1, 0x53, 0xe2, 0x9f, 0x5f, 0xb4, 0xc4, 0x09, 0x78, 0x00, 0x00, 0x15, 0xcc, 0xd9, 0x03, 0x5a, 0xa1, 0x6a, 0x48, 0x94, 0x40, 0x04, 0x84, 0x14, 0xcd, 0xc4, 0xe4, 0xe4, 0x9d, 0xf1, 0x4e, 0xbd, 0x18, 0x6d, 0x19, 0xd2, 0xfe, 0xdd, 0x43, 0x95, 0x3d, 0xf5, 0xe0, 0x04, 0xa2, 0xe0, 0x33, 0x1a, 0xc8, 0x97, 0xe9, 0x36, 0x72, 0xc1, 0xf1, 0xaa, 0x3a, 0x0d, 0xca, 0x85, 0x5d, 0x5d, 0xae, 0x01, 0x96, 0xb0, 0x61, 0x7a, 0xb8, 0xa4, 0x60, 0x6e, 0xc5, 0x29, 0x3b, 0x84, 0x81, 0xe3, 0x14, 0x97, 0x5e, 0x0a, 0x30, 0x5b, 0xf2, 0x99, 0xec, 0x7c, 0xd3, 0xfd, 0x78, 0x80, 0xf8, 0xe3, 0xf1, 0x98, 0x70, 0x8c, 0xac, 0xf9, 0x5b, 0x51, 0xa3, 0x93, 0xeb, 0xe3, 0x9c, 0xae, 0x11, 0x8c, 0x19, 0x34, 0x3c, 0x2c, 0x9b, 0x9c, 0x4f, 0x7b, 0xd9, 0x93, 0x20, 0xfc, 0x4d, 0x7d, 0x48, 0xd8, 0xf2, 0xde, 0x03, 0x19, 0x67, 0xb1, 0x60, 0x62, 0xea, 0x29, 0x56, 0x75, 0xaf, 0x1a, 0x47, 0x10, 0x5d, 0x44, 0xee, 0xf8, 0xb4, 0x0f, 0x04, 0xb4, 0x50, 0x98, 0x03, 0xdf, 0xd9, 0xe8, 0xc0, 0xe7, 0xcd, 0xb8, 0xd3, 0xbf, 0x99, 0xc0, 0xed, 0x2e, 0x16, 0x70, 0xf0, 0x41, 0xf1, 0x5f, 0x5a, 0x34, 0xd0, 0x85, 0x98, 0xad, 0xda, 0x20, 0xf9, 0xf7, 0xa9, 0x4d, 0x6a, 0x4f, 0x56, 0x7e, 0xec, 0xfd, 0x13, 0x3c, 0x55, 0x9e, 0xa3, 0xce, 0x48, 0xd9, 0x84, 0xab, 0xf0, 0x54, 0xc0, 0x5d, 0x30, 0x65, 0xad, 0x40, 0x7f, 0xcb, 0x1a, 0x65, 0x3e, 0x63, 0x65, 0x10, 0x1c, 0x90, 0x56, 0xf5, 0x8e, 0x90, 0x96, 0xb9, 0xb6, 0x62, 0x2e, 0x1c, 0xb3, 0x38, 0x6a, 0xf6, 0x29, 0x9f, 0x1c, 0x67, 0xa3, 0xea, 0xbc, 0x26, 0x65, 0x92, 0xcb, 0xca, 0xeb, 0xa9, 0x27, 0x3e, 0xa8, 0xc5, 0xc6, 0x89, 0x86, 0x63, 0x5c, 0x47, 0xbe, 0x98, 0x06, 0x72, 0x51, 0x36, 0x70, 0xa9, 0x8d, 0xdb, 0xf7, 0xeb, 0xed, 0xf4, 0xd3, 0xbe, 0x9a, 0x0f, 0x0c, 0x3a, 0x87, 0xdb, 0x87, 0x17, 0x2a, 0x7e, 0xb0, 0x01, 0x62, 0x01, 0x1c, 0xdf, 0x2c, 0x9f, 0x4d, 0xeb, 0xb5, 0x0c, 0x8d, 0xf8, 0x4b, 0xc8, 0x7d, 0x23, 0xd4, 0x53, 0x20, 0x82, 0xec, 0xd5, 0x24, 0x09, 0xea, 0x2d, 0x8b, 0x2a, 0x02, 0x24, 0x27, 0x12, 0xcc, 0x63, 0x3c, 0xbf, 0xc5, 0x1b, 0x30, 0x2c, 0xdc, 0x26, 0x36, 0xa1, 0xf9, 0x32, 0x83, 0x6b, 0x70, 0xa9, 0x9a, 0x71, 0x13, 0x41, 0x4b, 0x47, 0x09, 0xf3, 0x6a, 0xf1, 0xce, 0x77, 0xa7, 0x41, 0x27, 0xd1, 0x08, 0xf9, 0xcc, 0xbc, 0x9b, 0xa2, 0x0c, 0xb5, 0x3a, 0xd0, 0x12, 0xf1, 0x09, 0xa8, 0x08, 0x73, 0x51, 0xe0, 0x99, 0xe0, 0x8b, 0x10, 0x6c, 0x2f, 0x1f, 0xb9, 0x00, 0x57, 0x53, 0x7b, 0x44, 0x1c, 0xff, 0x91, 0x0b, 0x98, 0x15, 0xdd, 0xb8, 0xfc, 0x59, 0x7c, 0x1b, 0x86, 0x64, 0xc8, 0xa5, 0x7b, 0xcb, 0x64, 0x39, 0xac, 0xd8, 0x6b, 0xe9, 0x44, 0x95, 0xa4, 0x3a, 0x12, 0x49, 0x69, 0x43, 0xa4, 0xb1, 0x67, 0x03, 0x80, 0x73, 0xfb, 0x99, 0x3c, 0x4e, 0x5e, 0xa6, 0x5e, 0x59, 0x3e, 0xba, 0xbd, 0x75, 0x0f, 0x40, 0x86, 0x29, 0x2b, 0x5f, 0x18, 0x6f, 0xb9, 0x5e, 0xe7, 0x79, 0xb6, 0x6b, 0xe8, 0xae, 0x8f, 0x26, 0x5c, 0x83, 0xac, 0xe6, 0x47, 0xe8, 0xed, 0x4a, 0x98, 0x4d, 0x0d, 0x55, 0x80, 0x73, 0xee, 0x1b, 0x63, 0x61, 0xa2, 0xbb, 0x0c, 0x72, 0x40, 0x01, 0xad, 0x8d, 0x29, 0x3f, 0xca, 0xc5, 0x0b, 0xd5, 0x57, 0x6b, 0x86, 0x24, 0x3a, 0x97, 0xe7, 0xb7, 0xf2, 0x63, 0x14, 0x78, 0xee, 0xb6, 0x00, 0x23, 0x7e, 0x04, 0xd6, 0xca, 0xc6, 0x9a, 0x11, 0xfd, 0x00, 0xbd, 0x40, 0x6c, 0xbc, 0x24, 0xd9, 0xc8, 0x4c, 0x30, 0xa2, 0xcb, 0x01, 0x5d, 0xfe, 0xa5, 0x7c, 0x75, 0x90, 0xf0, 0x77, 0x14, 0xc3, 0x7e, 0x69, 0x78, 0xea, 0xdd, 0xdd, 0xf9, 0xfd, 0xbc, 0x78, 0x68, 0xfa, 0x4e, 0xb8, 0x28, 0x12, 0x28, 0xac, 0x0a, 0x55, 0x66, 0x3e, 0x8a, 0x81, 0x32, 0xd4, 0x25, 0xda, 0x37, 0xea, 0x75, 0xd4, 0x79, 0xc1, 0x4b, 0xb0, 0x28, 0xe5, 0x4f, 0x20, 0xee, 0xc6, 0x0c, 0x96, 0xfb, 0x2c, 0x66, 0xcf, 0x48, 0xcb, 0x5d, 0x36, 0x27, 0xf5, 0x47, 0x81, 0xe6, 0x05, 0xb5, 0x43, 0xaf, 0x35, 0x19, 0x3d, 0xe5, 0x04, 0x76, 0x77, 0x90, 0x15, 0xae, 0xc9, 0xca, 0xaa, 0x19, 0xa6, 0x4a, 0x69, 0x34, 0xf3, 0x89, 0xf1, 0x83, 0x47, 0xe4, 0x89, 0x28, 0xe2, 0x19, 0x91, 0xfb, 0xbc, 0x58, 0xd1, 0x7a, 0x1b, 0x52, 0x15, 0xc7, 0xb9, 0xf5, 0xac, 0x46, 0xfd, 0xf9, 0xf8, 0x77, 0x1b, 0xd4, 0xbc, 0xb6, 0x27, 0x60, 0x9a, 0x7f, 0xb5, 0xbd, 0x8a, 0x86, 0xa1, 0x79, 0x8e, 0x76, 0xe0, 0xd4, 0x65, 0x5a, 0xfd, 0x6b, 0xe8, 0x23, 0x0a, 0xcf, 0x97, 0xa3, 0x7d, 0x11, 0xcc, 0x10, 0xfd, 0x36, 0x39, 0x91, 0x25, 0x66, 0x74, 0x97, 0xd7, 0xc4, 0x14, 0xda, 0xc6, 0x03, 0x46, 0x08, 0x1e, 0x38, 0x74, 0xb8, 0x68, 0x15, 0x69, 0x50, 0xcc, 0xf5, 0x8b, 0x61, 0xdf, 0x01, 0xd7, 0xb2, 0x1e, 0x3e, 0x9c, 0x55, 0x5c, 0xd5, 0x97, 0x70, 0x65, 0xfb, 0x35, 0x60, 0xdf, 0x10, 0xe5, 0x3d, 0x61, 0xbc, 0xb3, 0x95, 0xdf, 0x06, 0x8d, 0x28, 0xc9, 0x20, 0xf8, 0xee, 0x11, 0x3d, 0xaf, 0xbe, 0x80, 0x87, 0x79, 0x76, 0xc0, 0x9d, 0xee, 0xc0, 0x2c, 0x26, 0xc2, 0x3d, 0x89, 0x2f, 0x1b, 0x1c, 0x5c, 0x44, 0x24, 0x45, 0xb5, 0x4b, 0xae, 0x65, 0x4d, 0x45, 0xbb, 0x8a, 0xf6, 0xd3, 0xc6, 0x7f, 0x2e, 0x7a, 0x30, 0xe7, 0xa5, 0xe7, 0x36, 0xd9, 0xef, 0x29, 0x2f, 0x83, 0x36, 0x18, 0xb3, 0xe7, 0x2a, 0x6c, 0xf0, 0x60, 0x0d, 0x49, 0x78, 0x96, 0xa7, 0x94, 0xcc, 0x25, 0xed, 0x50, 0xef, 0x11, 0x75, 0x2e, 0x91, 0x2a, 0x16, 0xd0, 0x09, 0x7f, 0x35, 0x14, 0x16, 0xe8, 0x89)
        
        decryptData_Server(rawData: rawData)
        
    }
    
    func decryptData (rawData: [UInt8]) {
        var length = rawData.count
        
        encrypt.decryptBuf(with: &read_ctx, buffer: UnsafeMutablePointer<UInt8>(mutating: rawData), length: &length)
        
        print("client length: ", length)
        
        var result = ""
        for (index, data) in rawData.enumerated() {
            if index < length {
                result += NSString(format:"%02X ", data) as String
            }
        }
        print(result)
        
        let data = NSData(bytes: rawData, length: rawData.count)
        let dogString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
        print(dogString ?? "")
    }
    
    func decryptData_Server (rawData: [UInt8]) {
        var length = rawData.count
        
        encrypt_server.decryptBuf(with: &read_ctx_server, buffer: UnsafeMutablePointer<UInt8>(mutating: rawData), length: &length)
        
        print("server length: ", length)
        
        var result = ""
        for (index, data) in rawData.enumerated() {
            if index < length {
                result += NSString(format:"%02X ", data) as String
            }
        }
        print(result)
        
        let data = NSData(bytes: rawData, length: rawData.count)
        let dogString = NSString(data: data as Data, encoding: String.Encoding.utf8.rawValue)
        print(dogString)
    }
}
