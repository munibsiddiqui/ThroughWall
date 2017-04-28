//
//  RuleProxySelectionTableViewController.swift
//  ThroughWall
//
//  Created by Bin on 13/04/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class RuleProxySelectionTableViewController: UITableViewController {

    var availableOptions = [String]()
    private var selectedIndex = -1
    private var _oriSelectedIndex = -1
    var oriSelectedIndex: Int {
        set {
            _oriSelectedIndex = newValue
            selectedIndex = newValue
        }
        get {
            return _oriSelectedIndex
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if selectedIndex != oriSelectedIndex {
//            NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNewRuleValueUpdate), object: nil, userInfo: ["newValue": availableOptions[selectedIndex]])
            
            let notifcation = Notification(name: Notification.Name(rawValue: kNewRuleValueUpdate), object: nil, userInfo: ["newValue": availableOptions[selectedIndex]])
            NotificationCenter.default.post(notifcation)
            
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return availableOptions.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)

        // Configure the cell...

        cell.textLabel?.text = availableOptions[indexPath.row]

        switch availableOptions[indexPath.row].lowercased() {
        case "direct":
            cell.textLabel?.textColor = UIColor.green
        case "proxy":
            cell.textLabel?.textColor = UIColor.orange
        case "reject":
            cell.textLabel?.textColor = UIColor.red
        default:
            break
        }

        if indexPath.row == selectedIndex {
            cell.accessoryType = .checkmark
        }

        return cell
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let oldIndexPath = IndexPath(row: selectedIndex, section: 0)
        tableView.cellForRow(at: oldIndexPath)?.accessoryType = .none
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        selectedIndex = indexPath.row
    }


}
