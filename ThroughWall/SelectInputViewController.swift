//
//  SelectInputViewController.swift
//  ThroughWall
//
//  Created by Bin on 17/11/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit

class SelectInputViewController: UITableViewController,UITextFieldDelegate {

    var item = ""
    var presetSelections = [String]()
    var customSelection = [String]()
    var selected = ""
    var delegate: ConfigureViewController? = nil
    
    var selectedIndex = -1;

    
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
        let temp = presetSelections + customSelection
        
        delegate?.updateSelectedResult(item, selected: temp[selectedIndex])
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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
        return presetSelections.count + customSelection.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.row < presetSelections.count {
            //preset
            let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath)
            cell.textLabel?.text = presetSelections[indexPath.row]
            if selected == presetSelections[indexPath.row] {
                cell.accessoryType = .checkmark
                selectedIndex = indexPath.row
            }
            return cell
        }else{
            //custom
            let cell = tableView.dequeueReusableCell(withIdentifier: "inputCell", for: indexPath)
            let textField = cell.viewWithTag(100) as! UITextField
            textField.text = customSelection[indexPath.row - presetSelections.count]
            textField.delegate = self
            if selected == textField.text {
                cell.accessoryType = .checkmark
                selectedIndex = indexPath.row
            }
            return cell
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        selected = textField.text!
        
        return true
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let oldIndexPath = IndexPath(row: selectedIndex, section: 0)
        tableView.cellForRow(at: oldIndexPath)?.accessoryType = .none
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        selectedIndex = indexPath.row
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
