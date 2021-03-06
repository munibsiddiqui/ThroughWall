//
//  RulleListViewTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 27/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import CocoaLumberjack

class RuleMainViewTableViewController: UITableViewController, URLSessionDownloadDelegate, UIDocumentMenuDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate {
    var globalModeSwitch = UISwitch()
    var downloadTask: URLSessionDownloadTask!
    let downloadFilePath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/" + configFileName
    var backgroundView = UIView()
//    var downloadProgress = UITextField()
    var downloadIndicator = UIActivityIndicatorView()
//    var hiddenHitTimes = 0

    var isImportingRule = true


    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor

        readSettings()
        globalModeSwitch.addTarget(self, action: #selector(globalModeSwitchDidChange(_:)), for: .valueChanged)

        setTopArear()

        backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        backgroundView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        backgroundView.backgroundColor = UIColor.darkGray
        backgroundView.layer.cornerRadius = 10
        backgroundView.clipsToBounds = true

        downloadIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        downloadIndicator.center = CGPoint(x: 50, y: 50)
        downloadIndicator.activityIndicatorViewStyle = .whiteLarge
        backgroundView.addSubview(downloadIndicator)
        downloadIndicator.startAnimating()

        backgroundView.isHidden = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !view.subviews.contains(backgroundView) {
            view.addSubview(backgroundView)
        }
        backgroundView.center = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setTopArear() {
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.title = "Config"
    }

    func image(fromColor color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsGetCurrentContext()
        return image!
    }


    @objc func globalModeSwitchDidChange(_ sender: UISwitch) {
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
        return 4
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
        case 3:
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
            return " Import & Export Rule Files"
        case 2:
            return " View Rules"
        case 3:
            return " Import & Export Servers"
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
            view.backgroundColor = veryLightGrayUIColor
            view.addSubview(label)
            return view
        } else {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            view.backgroundColor = veryLightGrayUIColor
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
                cell.accessoryType = .none
            case 1:
                cell.textLabel?.text = "Test Rule"
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Import Rule"
            case 1:
                cell.textLabel?.text = "Reset to Default"
            case 2:
                cell.textLabel?.text = "Export Rule"
            default:
                break
            }
            cell.accessoryView = nil
            cell.accessoryType = .none
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "As List"
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "As Raw TXT"
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            if indexPath.row == 0 {
                cell.textLabel?.text = "Import Servers (need RESTART app)"
            } else {
                cell.textLabel?.text = "Export Servers"
            }

            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            return cell
        default:
            break
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
        return cell
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let rect = tableView.rectForRow(at: indexPath)
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
                //import
                importRuleFile(withRect: rect)
            case 1:
                useDefaultRule()
            case 2:
                //export
                exportRuleToCloud(withSourceRect: rect)
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
            default:
                break
            }
        case 3:
//            performSegue(withIdentifier: "icloudSync", sender: nil)
            if indexPath.row == 0 {
                importSetverFromCloud(withSourceRect: rect)
            } else {
                exportServersToCloud(withSourceRect: rect)
            }

        default:
            break
        }
    }

    // MARK: - Import & Export Servers

    func importSetverFromCloud(withSourceRect sourceRect: CGRect) {
        let importMenu = UIDocumentMenuViewController(documentTypes: ["public.text", "public.data", "public.pdf", "public.doc"], in: .import)
        importMenu.delegate = self
        importMenu.modalPresentationStyle = .formSheet
        if let popoverPresentationController = importMenu.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = sourceRect
        }
        isImportingRule = false
        present(importMenu, animated: true, completion: nil)
    }

    func exportServersToCloud(withSourceRect sourceRect: CGRect) {
        guard let url = SiteConfigController().getBackupSiteConfigsURL() else {
            return
        }
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = sourceRect
        }
        present(activityViewController, animated: true, completion: nil)
    }

    // MARK: - Import & Export Rule File

    func importRuleFile(withRect rect: CGRect) {

        let listController = UIAlertController(title: "Import Rule Files From", message: nil, preferredStyle: .actionSheet)

        let fromURLItem = UIAlertAction(title: "URL", style: .default, handler: { (_) in
            self.popTextFieldForURLInput()
        })
        listController.addAction(fromURLItem)

        let localDocumentItem = UIAlertAction(title: "Document", style: .default, handler: { (_) in
            self.popFileListInLocalFile(withSourceRect: rect)
        })
        listController.addAction(localDocumentItem)

        let cloudItem = UIAlertAction(title: "Cloud", style: .default, handler: { (_) in
            self.importRuleFromCloud(withSourceRect: rect)
        })
        listController.addAction(cloudItem)


        let cancelItem = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        listController.addAction(cancelItem)

        if let popoverPresentationController = listController.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = rect
        }

        present(listController, animated: true, completion: nil)

    }

    func importRuleFromCloud(withSourceRect sourceRect: CGRect) {
        let importMenu = UIDocumentMenuViewController(documentTypes: ["public.text", "public.data", "public.pdf", "public.doc"], in: .import)
        importMenu.delegate = self
        importMenu.modalPresentationStyle = .formSheet
        if let popoverPresentationController = importMenu.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = sourceRect
        }
        isImportingRule = true
        present(importMenu, animated: true, completion: nil)
    }

    func exportRuleToCloud(withSourceRect sourceRect: CGRect) {
        let url = URL(fileURLWithPath: RuleFileUpdateController().readCurrentRuleFileURL())
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let popoverPresentationController = activityViewController.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = sourceRect
        }
        present(activityViewController, animated: true, completion: nil)
    }


    func popFileListInLocalFile(withSourceRect sourceRect: CGRect) {
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

        if let popoverPresentationController = listController.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = sourceRect
        }

        present(listController, animated: true, completion: nil)
    }

    func listConfigFilesInDocument() -> [URL] {
        // Get the document directory url
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
//            print(directoryContents)

            // if you want to filter the directory contents you can do like this:
            let ruleFiles = directoryContents.filter { $0.pathExtension == "config" }
//            print("rule urls:", ruleFiles)
//            let ruleFileNames = ruleFiles.map { $0.deletingPathExtension().lastPathComponent }
//            print("rule list:", ruleFileNames)
            return ruleFiles
        } catch {
            DDLogError("\(error)")
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

    @objc func alertTextFieldDidChange(notification: NSNotification) {
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
                self.backgroundView.isHidden = false
            }

            downloadTask.resume()
        }
    }

    func saveToConfigFile(_ content: String) {
        let fileManager = FileManager.default
        fileManager.createFile(atPath: downloadFilePath, contents: content.data(using: String.Encoding.utf8), attributes: nil)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        if controller.documentPickerMode == .import {
            do {
                let content = try String(contentsOf: url, encoding: String.Encoding.utf8)
                if isImportingRule {
                    saveToConfigFile(content)
                    RuleFileUpdateController().updateRuleFileFromImportedFile(downloadFilePath)
                }else {
                    let fixContent = content.replacingOccurrences(of: "\r\n", with: "\n")
                    SiteConfigController().writeIntoSiteConfigFile(withContents: fixContent)
                }
            } catch {
                DDLogError("\(error)")
            }
        }
    }

    func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController) {
        print("we cancelled")
        dismiss(animated: true, completion: nil)
    }

    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let content = try String(contentsOf: location, encoding: String.Encoding.utf8)
            saveToConfigFile(content)
            RuleFileUpdateController().updateRuleFileFromImportedFile(downloadFilePath)
        } catch {
            DDLogError("\(error)")
        }
        DispatchQueue.main.async {
            self.backgroundView.isHidden = true
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
                self.backgroundView.isHidden = true
            }
        } else {
//            let percent = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)
//            DispatchQueue.main.async {
//                self.downloadProgress.text = "\(percent) %"
//            }
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
