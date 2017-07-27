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
//        tableView.doubleAction = #selector(doubleClicked(_:))


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
