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


    func readCurrentRuleFileContent() -> String {
        //if default, return file in bundle. if custom, return file in downlaod position
        var content = ""

        if getCurrentFileSource() == defaultFileSource {
            if let path = Bundle.main.path(forResource: "rule", ofType: "config") {
                do {
                    content = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
                } catch {
                    print(error)
                }
            }
        } else {
            let customPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/" + configFileName
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: customPath) {
                do {
                    content = try String(contentsOfFile: customPath, encoding: String.Encoding.utf8)
                } catch {
                    print(error)
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
            print(error)
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
            NSLog("\(error))")
        }
    }

    private func saveToRuleFile(withContent content: String) {
        let fileManager = FileManager.default

        let classifications = content.components(separatedBy: "[")

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
                        filehandle.closeFile()
                    } catch {
                        print(error)
                        return
                    }
                } else if name == "URL Rewrite" {
                    //store rule into file
                    guard var url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
                        return
                    }
                    url.appendPathComponent(rewriteFileName)

                    fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)

                    do {
                        let filehandle = try FileHandle(forWritingTo: url)
                        for item in items {
                            filehandle.seekToEndOfFile()
                            filehandle.write("\(item)\n".data(using: String.Encoding.utf8)!)
                        }
                        filehandle.synchronizeFile()
                        filehandle.closeFile()
                    } catch {
                        print(error)
                        return
                    }
                }
            }
        }
    }

}

class RuleMainViewTableViewController: UITableViewController, URLSessionDownloadDelegate {
    var globalModeSwitch = UISwitch()
    var downloadTask: URLSessionDownloadTask!
    let downloadFilePath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/" + configFileName


    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground

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
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch section {
        case 0:
            return 2
        case 1:
            return 3
        case 2:
            return 2
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return " Actions"
        case 1:
            return "Import Rule Files"
        case 2:
            return " View rules"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let _ = self.tableView(tableView, titleForHeaderInSection: section) {
            return 60
        }
        return 40
    }


//    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//        if section == 0 {
//            return 60
//        }else{
//            return 0
//        }
//    }
//
//    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
//        if section == 0 {
//            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 38))
//            view.backgroundColor = UIColor.groupTableViewBackground
//            return view
//        }else {
//            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
//            view.backgroundColor = UIColor.groupTableViewBackground
//            return view
//        }
//    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = self.tableView(tableView, titleForHeaderInSection: section) {
            //global mode section
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            let label = UILabel(frame: CGRect(x: 10, y: 35, width: tableView.frame.width, height: 20))
            label.text = header
            label.textColor = UIColor.gray
            label.font = UIFont.boldSystemFont(ofSize: 16)
            view.backgroundColor = UIColor.groupTableViewBackground
            view.addSubview(label)
            return view
        } else {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            view.backgroundColor = UIColor.groupTableViewBackground
            return view
        }
    }



    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            // action section
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Global mode"
                cell.accessoryView = globalModeSwitch
            case 1:
                cell.textLabel?.text = "Test Rule"
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "From URL"
            case 1:
                cell.textLabel?.text = "From Local Document"
            case 2:
                cell.textLabel?.text = "Reset to Default"
            default:
                break
            }
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "As List"
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "As Raw TXT"
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            return cell
        default:
            break
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
        return cell
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 1:
                performSegue(withIdentifier: "showTestRule", sender: nil)
            default:
                break
            }
        case 1:
            switch indexPath.row {
            case 0:
                popTextFieldForURLInput()
            case 1:
                popFileListInLocalFile()
            case 2:
                useDefaultRule()
            default:
                break
            }
        case 2:
            switch indexPath.row {
            case 0:
                performSegue(withIdentifier: "showRuleList", sender: nil)
            case 1:
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "rawRuleTXTView") as! RawRuleTXTViewController
                
                self.navigationController?.pushViewController(vc, animated: true)
//                performSegue(withIdentifier: "showRawTXT", sender: nil)
            default:
                break
            }
        default:
            break
        }
    }

    // MARK: - Import Rule File

    func popFileListInLocalFile() {
        //        let alertController = UIAlertController(title: "Input URL", message: nil, preferredStyle: .alert)
        let listController = UIAlertController(title: "Files in Document", message: nil, preferredStyle: .actionSheet)
        let fileURLs = listConfigFilesInDocument()
        let ruleFileNames = fileURLs.map { $0.deletingPathExtension().lastPathComponent }
        for (index, ruleFileName) in ruleFileNames.enumerated() {
            let fileItem = UIAlertAction(title: ruleFileName, style: .default, handler: { (_) in
                RuleFileUpdateController().updateRuleFileFromImportedFile(fileURLs[index].path)
                //                self.ruleItems = Rule.sharedInstance.itemsInRuleFile()
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            })
            listController.addAction(fileItem)
        }

        let cancelItem = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        listController.addAction(cancelItem)
        present(listController, animated: true, completion: nil)
    }

    func listConfigFilesInDocument() -> [URL] {
        // Get the document directory url
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            print(directoryContents)

            // if you want to filter the directory contents you can do like this:
            let ruleFiles = directoryContents.filter { $0.pathExtension == "config" }
            print("rule urls:", ruleFiles)
            let ruleFileNames = ruleFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("rule list:", ruleFileNames)
            return ruleFiles
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        return []
    }


    func useDefaultRule() {
        let alertController = UIAlertController(title: "Using Default Rule?", message: "This will overwrite current rule", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Yes", style: .destructive, handler: { (_) in
            RuleFileUpdateController().forceUpdateRuleFileFromBundleFile()
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(cancelAction)
        alertController.addAction(deleteAction)

        self.present(alertController, animated: true, completion: nil)

    }


    func popTextFieldForURLInput() {
        let alertController = UIAlertController(title: "Input URL", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { (textFiled) in
            textFiled.placeholder = "URL"
            NotificationCenter.default.addObserver(self, selector: #selector(RuleMainViewTableViewController.alertTextFieldDidChange(notification:)), name: NSNotification.Name.UITextFieldTextDidChange, object: textFiled)
        })

        let okAction = UIAlertAction(title: "Done", style: .default, handler: { (_) in
            if let url = alertController.textFields?.first?.text {
                self.downloadRuleFrom(url)
            }
        })
        okAction.isEnabled = false
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)

        self.present(alertController, animated: true, completion: nil)
    }

    func alertTextFieldDidChange(notification: NSNotification) {
        if let alertContorller = self.presentedViewController as? UIAlertController {
            guard let url = alertContorller.textFields?.first?.text else {
                return
            }
            guard let okAction = alertContorller.actions.last else {
                return
            }
            okAction.isEnabled = url.lengthOfBytes(using: String.Encoding.utf8) > 0
        }
    }


    func downloadRuleFrom(_ url: String) {
        //Download
        if let confURL = URL(string: url) {
            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
            downloadTask = session.downloadTask(with: confURL)
            DispatchQueue.main.async {
//                self.downloadIndicator.startAnimating()
//                self.downloadProgress.text = "0 %"
//                self.downloadProgress.isHidden = false
            }

            downloadTask.resume()
        }
    }

    func saveToConfigFile(_ content: String) {
        let fileManager = FileManager.default
        fileManager.createFile(atPath: downloadFilePath, contents: content.data(using: String.Encoding.utf8), attributes: nil)
    }


    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let content = try String(contentsOf: location, encoding: String.Encoding.utf8)
            saveToConfigFile(content)
            RuleFileUpdateController().updateRuleFileFromImportedFile(downloadFilePath)
        } catch {
            print(error)
        }
        DispatchQueue.main.async {
//            self.downloadIndicator.stopAnimating()
//            self.downloadProgress.text = "Done"
//            UIView.animate(withDuration: 1, animations: {
//                self.downloadProgress.alpha = 0
//            }, completion: { (succeed) in
//                self.downloadProgress.isHidden = true
//                self.downloadProgress.alpha = 1
//            })
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {
            DispatchQueue.main.async {
//                self.downloadProgress.isHidden = true
//                self.downloadIndicator.stopAnimating()

            }
        } else {
//            let percent = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)
            DispatchQueue.main.async {
//                self.downloadProgress.text = "\(percent) %"
            }
        }
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
