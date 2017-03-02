//
//  RuleViewController.swift
//  ThroughWall
//
//  Created by Bin on 29/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
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
        }else {
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
        }else {
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
        
        do{
            fileString = try String(contentsOfFile: urlString, encoding: String.Encoding.utf8)
        }catch {
            return
        }
        
        let classifications = fileString.components(separatedBy: "[")
        
        for classification in classifications {
            
            let components = classification.components(separatedBy: "]" )
            
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
                    url.appendPathComponent(ruleFielName)
                    
                    fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
                    
                    do {
                        let filehandle = try FileHandle(forWritingTo: url)
                        for item in items {
                            filehandle.seekToEndOfFile()
                            filehandle.write("\(item)\n".data(using: String.Encoding.utf8)!)
                        }
                        filehandle.synchronizeFile()
                        
                    }catch {
                        print(error)
                        return
                    }
                }
            }
        }
    }
}

class RuleViewController: UIViewController, UIPopoverPresentationControllerDelegate, URLSessionDownloadDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var downloadIndicator: UIActivityIndicatorView!
    @IBOutlet weak var downloadProgress: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var downloadTask: URLSessionDownloadTask!
    let downloadFilePath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0] + "/" + configFileName
    var ruleItems = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        downloadProgress.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(RuleViewController.ruleImportMethodChoosen(notification:)), name: NSNotification.Name(rawValue: kChoosenRuleImportMethod), object: nil)
        
        Rule.sharedInstance.analyzeRuleFile()
        ruleItems = Rule.sharedInstance.itemsInRuleFile()
        
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kChoosenRuleImportMethod), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ruleItems.count
    }
    
//    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        return "Current Rules"
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
        cell.textLabel?.text = ruleItems[indexPath.row]
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func ruleImportMethodChoosen(notification: NSNotification) {
        if let info = notification.userInfo?[kRuleImportMethodValue] as? Int {
            switch info {
            case 0:
                popTextFieldForURLInput()
            case 1:
                popFileListInLocalFile()
            case 2:
//                popQRScaner()
                useDefaultRule()
            default:
                break
            }
        }
    }
    
    func popTextFieldForURLInput() {
        let alertController = UIAlertController(title: "Input URL", message: nil, preferredStyle: .alert)
        alertController.addTextField(configurationHandler: { (textFiled) in
            textFiled.placeholder = "URL"
            NotificationCenter.default.addObserver(self, selector: #selector(RuleViewController.alertTextFieldDidChange(notification:)), name: NSNotification.Name.UITextFieldTextDidChange, object: textFiled)
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
                self.downloadIndicator.startAnimating()
                self.downloadProgress.text = "0 %"
                self.downloadProgress.isHidden = false
            }
            
            downloadTask.resume()
        }
    }
    
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do{
            let content =  try String(contentsOf: location, encoding: String.Encoding.utf8)
            saveToConfigFile(content)
            RuleFileUpdateController().updateRuleFileFromImportedFile(downloadFilePath)
        }catch{
            print(error)
        }
        DispatchQueue.main.async {
            self.downloadIndicator.stopAnimating()
            self.downloadProgress.text = "Done"
            UIView.animate(withDuration: 1, animations: {
                self.downloadProgress.alpha = 0
            }, completion: { (succeed) in
                self.downloadProgress.isHidden = true
                self.downloadProgress.alpha = 1
            })
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {

        if totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown {
            DispatchQueue.main.async {
                self.downloadProgress.isHidden = true
                self.downloadIndicator.stopAnimating()
                
            }
        }else{
            let percent = Int(totalBytesWritten * 100 / totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadProgress.text = "\(percent) %"
            }
        }

    }
    
    func saveToConfigFile(_ content: String) {
        let fileManager = FileManager.default
        fileManager.createFile(atPath: downloadFilePath, contents: content.data(using: String.Encoding.utf8), attributes: nil)
    }
    
    
    func popFileListInLocalFile() {
//        let alertController = UIAlertController(title: "Input URL", message: nil, preferredStyle: .alert)
        let listController = UIAlertController(title: "Files in Document", message: nil, preferredStyle: .actionSheet)
        let fileURLs = listConfigFilesInDocument()
        let ruleFileNames = fileURLs.map{ $0.deletingPathExtension().lastPathComponent }
        for (index, ruleFileName) in ruleFileNames.enumerated() {
            let fileItem = UIAlertAction(title: ruleFileName, style: .default, handler: { (_) in
                RuleFileUpdateController().updateRuleFileFromImportedFile(fileURLs[index].path)
                self.ruleItems = Rule.sharedInstance.itemsInRuleFile()
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
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
            print(directoryContents)
            
            // if you want to filter the directory contents you can do like this:
            let ruleFiles = directoryContents.filter{ $0.pathExtension == "config" }
            print("rule urls:",ruleFiles)
            let ruleFileNames = ruleFiles.map{ $0.deletingPathExtension().lastPathComponent }
            print("rule list:", ruleFileNames)
            return ruleFiles
        } catch let error as NSError {
            print(error.localizedDescription)
        }
        return []
    }
    
    func popQRScaner() {
        
    }
    
    func useDefaultRule() {
        RuleFileUpdateController().forceUpdateRuleFileFromBundleFile()
        ruleItems = Rule.sharedInstance.itemsInRuleFile()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "popover" {
            let popoverViewController = segue.destination
            popoverViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            popoverViewController.popoverPresentationController!.delegate = self
            
        }
    }
    
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

}
