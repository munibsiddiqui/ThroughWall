//
//  RuleListTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 30/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class RuleListTableViewController: UITableViewController {

    var ruleItems = [[String]]()
    var rewriteItems = [[String]]()
    
    var selectedIndex = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground
        
        NotificationCenter.default.addObserver(self, selector: #selector(RuleListTableViewController.ruleSaved(notification:)), name: NSNotification.Name(rawValue: kRuleSaved), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RuleListTableViewController.ruleDeleted(notification:)), name: NSNotification.Name(rawValue: kRuleDeleted), object: nil)
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kRuleSaved), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kRuleDeleted), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadItemsFromDisk()
        
    }
    
    func reloadItemsFromDisk() {
        ruleItems = Rule.sharedInstance.getCurrentRuleItems()
        rewriteItems = Rule.sharedInstance.getCurrentRewriteItems()
        
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func ruleSaved(notification: Notification) {
        if let value = notification.userInfo?["ruleItem"] as? [String] {
            if selectedIndex == -1 {
                ruleItems.insert(value, at: 0)
            }else {
                ruleItems[selectedIndex - rewriteItems.count] = value
            }
            let content = makeRulesIntoContent()
            RuleFileUpdateController().saveToCustomRuleFile(withContent: content)
        }else if let value = notification.userInfo?["rewriteItem"] as? [String] {
            if selectedIndex == -1 {
                rewriteItems.insert(value, at: 0)
            }else {
                rewriteItems[selectedIndex] = value
            }
            let content = makeRulesIntoContent()
            RuleFileUpdateController().saveToCustomRuleFile(withContent: content)
        }
        reloadItemsFromDisk()
    }
    
    func ruleDeleted(notification: Notification) {
        if selectedIndex ==  -1 {
            return
        }
        if selectedIndex < rewriteItems.count {
            rewriteItems.remove(at: selectedIndex)
        }else{
            ruleItems.remove(at: selectedIndex - rewriteItems.count)
        }
        selectedIndex = -1
        let content = makeRulesIntoContent()
        RuleFileUpdateController().saveToCustomRuleFile(withContent: content)
        reloadItemsFromDisk()
    }
    
    
    func makeRulesIntoContent() -> String {
        var content = "[URL Rewrite]\n"
        
        for rewriteItem in rewriteItems {
            let tmp = rewriteItem.joined(separator: " ")
            content.append(tmp + "\n")
        }
        
        content.append("[Rule]\n")
        
        for ruleItem in ruleItems {
            let tmp = ruleItem.joined(separator: ",")
            content.append(tmp + "\n")
        }
        
        return content
    }
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return rewriteItems.count + ruleItems.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "listCell", for: indexPath)
        
        if indexPath.row < rewriteItems.count {
            let item = rewriteItems[indexPath.row]
            
            cell.textLabel?.text = item[0]
            cell.detailTextLabel?.text = item[1]
        }else{
            let item = ruleItems[indexPath.row - rewriteItems.count]
            
            cell.textLabel?.text = item[1]
            cell.detailTextLabel?.attributedText = makeAttributeDescription(withMatchRule: item[0], andProxyRule: item[2])
        }

        return cell
    }

    
    func makeAttributeDescription(withMatchRule matchRule: String, andProxyRule proxyRule: String) -> NSAttributedString {
        let attributeDescription = NSMutableAttributedString(string: "")
        
        let attributeRequestType = NSAttributedString(string: matchRule, attributes: [NSForegroundColorAttributeName: UIColor.lightGray])
        attributeDescription.append(attributeRequestType)
        attributeDescription.append(NSAttributedString(string: " "))
        
        switch proxyRule.lowercased() {
        case "direct":
            let attributeRule = NSAttributedString(string: proxyRule, attributes: [NSForegroundColorAttributeName: UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)])
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        selectedIndex = indexPath.row
        performSegue(withIdentifier: "showRuleDetail", sender: nil)
    }
    
    @IBAction func addNewRule(_ sender: UIBarButtonItem) {
        selectedIndex = -1
        performSegue(withIdentifier: "showRuleDetail", sender: nil)
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showRuleDetail" {
            if let desti = segue.destination as? RuleDetailTableViewController {
                if selectedIndex != -1 {
                    let item: [String]
                    if selectedIndex < rewriteItems.count {
                        item = rewriteItems[selectedIndex]
                        desti.rewriteItem = item
                    }else{
                        item = ruleItems[selectedIndex - rewriteItems.count]
                        desti.ruleItem = item
                    }
                    desti.showDelete = true
                }else {
                    desti.showDelete = false
                }
            }
        }
    }
}
