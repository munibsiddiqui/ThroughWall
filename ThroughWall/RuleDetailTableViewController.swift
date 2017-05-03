//
//  RuleDetailTableViewController.swift
//  ThroughWall
//
//  Created by Bingo on 30/03/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class RuleDetailTableViewController: UITableViewController, UITextFieldDelegate {

    var ruleItem = [String]()
    var rewriteItem = [String]()
    var fromLabel: UITextField? = nil
    var toLabel: UITextField? = nil
    var ipDomainLabel: UITextField? = nil
    var showDelete = false
    var selectedRow  = -1
    
    let options = ["URL Rewrite", "Rule"]
    let types = ["DOMAIN-SUFFIX", "DOMAIN", "DOMAIN-KEYWORD", "IP-CIDR"]
    let policy = ["Proxy", "Direct", "Reject"]

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground

        NotificationCenter.default.addObserver(self, selector: #selector(RuleDetailTableViewController.didSelectedNewValue(notification:)), name: NSNotification.Name(rawValue: kNewRuleValueUpdate), object: nil)
        
        
        if showDelete {
            navigationItem.title = "Edit"
        } else {
            navigationItem.title = "Add"
        }

        if ruleItem.isEmpty && rewriteItem.isEmpty {
            ruleItem = ["DOMAIN-SUFFIX", "", "Proxy"]
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kNewRuleValueUpdate), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func saveAndExit(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        if !ruleItem.isEmpty {
            let notifcation = Notification(name: Notification.Name(rawValue: kRuleSaved), object: nil, userInfo: ["ruleItem": ruleItem])
            NotificationCenter.default.post(notifcation)
        }else if !rewriteItem.isEmpty {
            let notifcation = Notification(name: Notification.Name(rawValue: kRuleSaved), object: nil, userInfo: ["rewriteItem": rewriteItem])
            NotificationCenter.default.post(notifcation)
        }
        
        let _ = navigationController?.popViewController(animated: true)
    }
    
    func didSelectedNewValue(notification: Notification) {
        if let newValue = notification.userInfo?["newValue"] as? String {
            switch selectedRow {
            case 0:
                if newValue == "URL Rewrite" {
                    ruleItem = []
                    rewriteItem = ["", ""]
                }else{
                    ruleItem = ["DOMAIN-SUFFIX", "", "Proxy"]
                    rewriteItem = []
                }
            case 1:
                ruleItem[0] = newValue
            case 2:
                ruleItem[2] = newValue
            default:
                break
            }
            selectedRow = -1
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else{
            return
        }
        if textField == toLabel {
            rewriteItem[1] = text
        } else if  textField == ipDomainLabel {
           ruleItem[1] = text
        }else if textField == fromLabel {
            rewriteItem[0] = text
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == toLabel {
            textField.endEditing(true)
        } else if  textField == ipDomainLabel {
            textField.endEditing(true)
        }else if textField == fromLabel {
            toLabel?.becomeFirstResponder()
        }
        return true
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if showDelete {
            return 2
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            if ruleItem.isEmpty {
                return 3
            }
            return 4
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1 {
            return 40
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        // Configure the cell...

        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "deleteCell", for: indexPath)
            return cell
        }

        if ruleItem.isEmpty {
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath)
                let label = cell.viewWithTag(1) as! UILabel
                label.text = "Option"
                let detailLabel = cell.viewWithTag(2) as! UILabel
                detailLabel.text = "URL Rewrite"
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "rewriteCell", for: indexPath)
                let label = cell.viewWithTag(1) as! UILabel
                label.text = "From"
                fromLabel = cell.viewWithTag(2) as? UITextField
                fromLabel?.text = rewriteItem[0]
                fromLabel?.placeholder = "Regular Expression"
                fromLabel?.returnKeyType = .continue
                fromLabel?.delegate = self
                return cell
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "rewriteCell", for: indexPath)
                let label = cell.viewWithTag(1) as! UILabel
                label.text = "To"
                toLabel = cell.viewWithTag(2) as? UITextField
                toLabel?.text = rewriteItem[1]
                toLabel?.placeholder = "e.g., http://www.google.com"
                toLabel?.delegate = self
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "deleteCell", for: indexPath)
                return cell
            }
        } else {
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath)
                let label = cell.viewWithTag(1) as! UILabel
                label.text = "Option"
                let detailLabel = cell.viewWithTag(2) as! UILabel
                detailLabel.text = "Rule"
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath)
                let label = cell.viewWithTag(1) as! UILabel
                label.text = "Type"
                let detailLabel = cell.viewWithTag(2) as! UILabel
                detailLabel.text = ruleItem[0]
                return cell
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath)
                let label = cell.viewWithTag(1) as! UILabel
                label.text = "Policy"
                let detailLabel = cell.viewWithTag(2) as! UILabel
                detailLabel.text = ruleItem[2]

                switch ruleItem[2].lowercased() {
                case "direct":
                    detailLabel.textColor = UIColor.init(red: 0.24, green: 0.545, blue: 0.153, alpha: 1.0)
                case "proxy":
                    detailLabel.textColor = UIColor.orange
                default:
                    detailLabel.textColor = UIColor.red
                }

                return cell
            case 3:
                let cell = tableView.dequeueReusableCell(withIdentifier: "ipdomainCell", for: indexPath)
                ipDomainLabel = cell.viewWithTag(2) as? UITextField
                ipDomainLabel?.text = ruleItem[1]
                ipDomainLabel?.placeholder = "IP or Domain"
                ipDomainLabel?.delegate = self
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: "deleteCell", for: indexPath)
                return cell
            }
        }
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.section == 1 {
            
            let alertController = UIAlertController(title: "Delete Rule", message: nil, preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
            
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: kRuleDeleted), object: nil)
                DispatchQueue.main.async {
                    let _ = self.navigationController?.popViewController(animated: true)
                }
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            
            alertController.addAction(cancelAction)
            alertController.addAction(deleteAction)
            
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        selectedRow = indexPath.row
        if ruleItem.isEmpty {
            if indexPath.row == 0 {
                performSegue(withIdentifier: "selectRuleDetail", sender: nil)
            }
        } else {
            if indexPath.row < 3 {
                performSegue(withIdentifier: "selectRuleDetail", sender: nil)
            }
        }
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let desti = segue.destination as? RuleProxySelectionTableViewController {
            switch selectedRow {
            case 0:
                desti.availableOptions = options
                if ruleItem.isEmpty {
                    desti.oriSelectedIndex = 0
                }else{
                    desti.oriSelectedIndex = 1
                }
            case 1:
                desti.availableOptions = types
                desti.oriSelectedIndex =  types.index(of: ruleItem[0])!
            default:
                desti.availableOptions = policy
                desti.oriSelectedIndex =  policy.index(of: ruleItem[2])!
            }
        }
    }


}
