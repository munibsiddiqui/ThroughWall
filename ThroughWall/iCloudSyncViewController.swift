//
//  iCloudSyncViewController.swift
//  ThroughWall
//
//  Created by Bingo on 05/08/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class iCloudSyncViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        setTopArear()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func setTopArear() {
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.title = "iCloud Sync Setting"
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

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return 2
        }
        return 3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return " Sync Server"
        case 1:
            return " Sync Rule Configs"
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
            switch indexPath.row {
            case 0:
                if let lastSyncTime = UserDefaults().value(forKey: kLastServerSyncTime) as? String {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "subtitleCell", for: indexPath)
                    cell.textLabel?.text = "Sync with iCloud"
                    cell.detailTextLabel?.text = lastSyncTime
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
                    cell.textLabel?.text = "Sync with iCloud"
                    return cell
                }
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
                cell.textLabel?.text = "Delete iCloud Servers"
                return cell
            default:
                break
            }
        case 1:
            switch indexPath.row {
            case 0:
                if let lastSyncTime = UserDefaults().value(forKey: kLastServerSyncTime) as? String {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "subtitleCell", for: indexPath)
                    cell.textLabel?.text = "Update to iCloud"
                    cell.detailTextLabel?.text = lastSyncTime
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
                    cell.textLabel?.text = "Update to iCloud"
                    return cell
                }
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
                cell.textLabel?.text = "Download from iCloud"
                return cell
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
                cell.textLabel?.text = "Clear from iCloud"
                return cell
            default:
                break
            }

        default:
            break
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
        return cell
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                syncServersWithiCloud()
            case 1:
                clearServersFromiCloud()
            default:
                break
            }
        case 1:
            break
        default:
            break
        }
    }

    func syncServersWithiCloud() {
        //get local
//        let serverContent = SiteConfigController().readSiteConfigsContent()
//        let servers = serverContent.components(separatedBy: "#\n")
        
        
        //download
        
        //compare
        
        //upload
//        for server in servers {
//            var items = server.components(separatedBy: "\n")
//            for item in items {
//                if item
//            }
//        }
        
    }

    func uploadServerToiCloud(withContent content: String) {
        CloudController().saveNewServerToiCloud(withContent: content) { (recordName, creationDate, error) in
            if let error = error {
                let alertController = UIAlertController(title: "Error", message: "Save server to iCloud failed with error: \(error)", preferredStyle: .alert)
                
                let action = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in
                    
                })
                
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    func clearServersFromiCloud() {

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

