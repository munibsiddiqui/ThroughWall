//
//  RulleListViewTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 27/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

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
            defaults?.synchronize()
        }
    }

    private func saveToRuleFile(fromURLString urlString: String) {
        let fileManager = FileManager.default
        var fileString = ""

        do {
            fileString = try String(contentsOfFile: urlString, encoding: String.Encoding.utf8)
        } catch {
            return
        }

        let classifications = fileString.components(separatedBy: "[")

        for classification in classifications {

            let components = classification.components(separatedBy: "]")

            if components.count == 2 {
                let name = components[0]
                let value = components[1]

                var returnKey = "\r\n"

                if !value.contains(returnKey) {
                    returnKey = "\n"
                    if !value.contains(returnKey) {
                        returnKey = ""
                    }
                }

                var items = value.components(separatedBy: returnKey)

                for (index, item) in items.enumerated().reversed() {
                    if item.hasPrefix("#") || item == "" {
                        items.remove(at: index)
                    }
                }

                if name == "Rule" {
                    //store rule into file
                    guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
                        return
                    }
                    url.appendPathComponent(ruleFileName)

                    fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)

                    do {
                        let filehandle = try FileHandle(forWritingTo: url)
                        for item in items {
                            filehandle.seekToEndOfFile()
                            filehandle.write("\(item)\n".data(using: String.Encoding.utf8)!)
                        }
                        filehandle.synchronizeFile()

                    } catch {
                        print(error)
                        return
                    }
                }
            }
        }
    }
}

class RuleListViewTableViewController: UITableViewController {

    var ruleItems = [[String]]()
    var globalModeSwitch = UISwitch()


    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        ruleItems = Rule.sharedInstance.getCurrentRuleItems()
        readSettings()
        globalModeSwitch.addTarget(self, action: #selector(globalModeSwitchDidChange(_:)), for: .valueChanged)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func globalModeSwitchDidChange(_ sender: UISwitch) {
        let defaults = UserDefaults.init(suiteName: groupName)
        defaults?.set(sender.isOn, forKey: globalModeSetting)
        defaults?.synchronize()
    }

    func readSettings() {
        let defaults = UserDefaults.init(suiteName: groupName)
        var globalMode = false

        if let global = defaults?.value(forKey: globalModeSetting) as? Bool {
            globalMode = global
        }

        DispatchQueue.main.async {
            self.globalModeSwitch.isOn = globalMode
        }
    }



    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 6
        case 1:
            return ruleItems.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Action"
        case 1:
            return "List"
        default:
            return nil
        }
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            // action section
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Add new item"
            case 1:
                cell.textLabel?.text = "view as TXT"
            case 2:
                cell.textLabel?.text = "Global mode"
                cell.accessoryView = globalModeSwitch
            case 3:
                cell.textLabel?.text = "Reset to Default"
            case 4:
                cell.textLabel?.text = "Import from URL"
            case 5:
                cell.textLabel?.text = "test rule"
            default:
                break
            }
            return cell
        case 1:
            //list section
            let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)
            let item = ruleItems[indexPath.row]

            cell.textLabel?.text = item[1]
            cell.detailTextLabel?.attributedText = makeAttributeDescription(withMatchRule: item[0], andProxyRule: item[2])

            return cell
        default:
            break
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
        return cell
    }


    func makeAttributeDescription(withMatchRule matchRule: String, andProxyRule proxyRule: String) -> NSAttributedString {
        let attributeDescription = NSMutableAttributedString(string: "")


//        switch matchRule {
//        case "DOMAIN":
//            let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.cyan])
//            attributeDescription.append(attributeRequestType)
//        case "DOMAIN-SUFFIX":
//            let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.yellow])
//            attributeDescription.append(attributeRequestType)
//        case "DOMAIN-MATCH":
//            fallthrough
//        case "DOMAIN-KEYWORD":
//            let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.brown])
//            attributeDescription.append(attributeRequestType)
//        case "IP-CIDR":
//            let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.purple])
//            attributeDescription.append(attributeRequestType)
//        default:
//            let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.red])
//            attributeDescription.append(attributeRequestType)
//        }

        let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.lightGray])
        attributeDescription.append(attributeRequestType)
        attributeDescription.append(NSAttributedString(string: " "))

        switch proxyRule.lowercased() {
        case "direct":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.green])
            attributeDescription.append(attributeRule)
        case "proxy":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.orange])
            attributeDescription.append(attributeRule)
        default:
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.red])
            attributeDescription.append(attributeRule)
        }
        return attributeDescription
    }


    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
