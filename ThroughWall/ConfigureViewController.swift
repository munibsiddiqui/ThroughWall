//
//  ConfigureViewController.swift
//  ZzzVPN
//
//  Created by Bin on 6/2/16.
//  Copyright © 2016 BinWu. All rights reserved.
//

import UIKit
import NetworkExtension

class ConfigureViewController: UITableViewController {

    var showDelete = false
    var proxyConfig = ProxyConfig()
    var inputFields = [UITextField]()
    let numberToolbar: UIToolbar = UIToolbar()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()

        if proxyConfig.currentProxy != "CUSTOM" {
            showDelete = false
            proxyConfig.currentProxy = "CUSTOM"
        } else {
            showDelete = true
        }

        numberToolbar.barStyle = UIBarStyle.default
        numberToolbar.items = [
            UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: self, action: nil),
            UIBarButtonItem(title: "Next", style: UIBarButtonItemStyle.plain, target: self, action: #selector(nextTextFieldAfterPortField))
        ]

        numberToolbar.sizeToFit()

        tableView.tableFooterView = UIView()
        tableView.backgroundColor = UIColor.groupTableViewBackground
        tableView.rowHeight = UITableViewAutomaticDimension;
        tableView.estimatedRowHeight = 44.0;
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        inputFields.sort() {
            if $0.convert($0.bounds, to: nil).origin.y < $1.convert($1.bounds, to: nil).origin.y {
                return true
            }
            return false
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func nextTextFieldAfterPortField() {
        inputFields[3].becomeFirstResponder()
    }

    func didExtractedQRCode(notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: kQRCodeExtracted), object: nil)
        if var ss = notification.userInfo?["string"] as? String {
            if let preRange = ss.range(of: "ss://") {
                ss.removeSubrange(preRange)
            }
            if let poundsignIndex = ss.range(of: "#")?.lowerBound {
                let removeRange = Range(uncheckedBounds: (lower: poundsignIndex, upper: ss.endIndex))
                ss.removeSubrange(removeRange)
            }
            ss = ss.padding(toLength: ((ss.characters.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            let decodeData = Data.init(base64Encoded: ss)
            if let decodestring = String.init(data: decodeData ?? Data(), encoding: String.Encoding.utf8) {
                let components = decodestring.components(separatedBy: ":")
                if components.count == 3 {
                    var method = components[0]
                    let passwordHost = components[1]
                    let port = components[2]

                    let components2 = passwordHost.components(separatedBy: "@")
                    if components2.count == 2 {
                        let password = components2[0]
                        let host = components2[1]

                        if let range = method.range(of: "-auth") {
                            method.removeSubrange(range)
                        }

//                        withUnsafePointer(to: &proxyConfig, { (p) in
//                            print("proxyconfig \(p)")
//                        })

//                        proxyConfig.currentProxy = "CUSTOM"
                        proxyConfig.setValue(byItem: "description", value: "\(host):\(port)")
                        proxyConfig.setValue(byItem: "server", value: host)
                        proxyConfig.setValue(byItem: "port", value: port)
                        proxyConfig.setValue(byItem: "password", value: password)
                        proxyConfig.setValue(byItem: "method", value: method)

                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                        return
                    }
                }
            }
        }

        let alertController = UIAlertController(title: "Extract QRCode Failed", message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)

        alertController.addAction(okAction)
        DispatchQueue.main.async {
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func getEncodedServerInfo() -> String {
        var result = ""

        if let value = proxyConfig.getValue(byItem: "method") {
            result = value
        } else {
            return ""
        }
        if let value = proxyConfig.getValue(byItem: "password") {
            result = result + ":" + value
        } else {
            return ""
        }
        if let value = proxyConfig.getValue(byItem: "server") {
            result = result + "@" + value
        } else {
            return ""
        }
        if let value = proxyConfig.getValue(byItem: "port") {
            result = result + ":" + value
        } else {
            return ""
        }
        let utf8Str = result.data(using: .utf8)
        if let base64Encoded = utf8Str?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0)) {
            return base64Encoded
        }
        return result
    }

    func showQRImage() {
        var str = getEncodedServerInfo()
        str = str.padding(toLength: ((str.characters.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        str = "ss://" + str
        let data = str.data(using: .isoLatin1)
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        let outputImage = filter?.outputImage

        if let outputImg = outputImage {
            let originalWidth = outputImg.extent.width
            let transform = CGAffineTransform(scaleX: 300.0 / originalWidth, y: 300.0 / originalWidth)
            let transformedImage = outputImg.applying(transform)

            let context = CIContext(options: nil)
            let imageRef = context.createCGImage(transformedImage, from: transformedImage.extent)
            let QRCImage = UIImage(cgImage: imageRef!)

            if let QRShow = storyboard?.instantiateViewController(withIdentifier: "QRCShowVC") as? QRShowViewController {

                QRShow.QRCImage = QRCImage

                present(QRShow, animated: true, completion: nil)
            }
        }
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if showDelete {
            return 3
        }
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return proxyConfig.containedItems.count
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 1 {
            return 40
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            //global mode section
            let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
            view.backgroundColor = UIColor.groupTableViewBackground
            return view
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let item = proxyConfig.containedItems[indexPath.row]

            if let _ = proxyConfig.getAvailableOptions(byItem: item) {
                //selection type
                let cell = tableView.dequeueReusableCell(withIdentifier: "selectionField", for: indexPath) as! SelectionFieldCell
                cell.item.text = proxyConfig.shownName[item]
                cell.selection.text = proxyConfig.getValue(byItem: item)
                return cell
            } else {
                //input type
                let cell = tableView.dequeueReusableCell(withIdentifier: "inputTextField", for: indexPath) as! InputTextFieldCell
                cell.item.text = proxyConfig.shownName[item]
                cell.itemDetail.text = proxyConfig.getValue(byItem: item)

                if let keyboardTypes = proxyConfig.getKeyboardType(byItem: item) {

                    for type in keyboardTypes {
                        switch type {
                        case "number":
                            cell.itemDetail.keyboardType = .numberPad
                        case "accessary":
                            cell.itemDetail.inputAccessoryView = numberToolbar
                        case "url":
                            cell.itemDetail.keyboardType = .URL
                        case "default":
                            cell.itemDetail.keyboardType = .default
                        case "next":
                            cell.itemDetail.returnKeyType = .next
                        case "done":
                            cell.itemDetail.returnKeyType = .done
                        case "secure":
                            cell.itemDetail.isSecureTextEntry = true
                        default:
                            break
                        }
                    }
                }

                if !inputFields.contains(cell.itemDetail) {
                    inputFields.append(cell.itemDetail)
                }

//                cell.itemDetail.placeholder = placeholder
                
                cell.valueChanged = {
                    self.proxyConfig.setValue(byItem: item, value: cell.itemDetail.text!)
                }

                cell.returnPressed = {
                    if let index = self.inputFields.index(of: cell.itemDetail) {
                        if index < self.inputFields.count - 1 {
                            self.inputFields[index + 1].becomeFirstResponder()
                        } else {
                            cell.itemDetail.resignFirstResponder()
                        }
                    }
                }

                return cell
            }
        } else if indexPath.section == 1 {
            if showDelete {
                let cell = tableView.dequeueReusableCell(withIdentifier: "deleteType", for: indexPath)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "importQRType", for: indexPath)
                return cell
            }
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "showQREx", for: indexPath)
            cell.backgroundColor = UIColor.groupTableViewBackground
            cell.separatorInset = UIEdgeInsetsMake(0.0, 0.0, 0.0, cell.bounds.size.width)
            return cell
        }

    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let item = proxyConfig.containedItems[indexPath.row]
            if let _ = proxyConfig.getAvailableOptions(byItem: item) {
                self.performSegue(withIdentifier: "selectInputDetail", sender: item)
            }
        } else if indexPath.section == 1 {
            if showDelete {
                let alertController = UIAlertController(title: "Delete Proxy Server?", message: nil, preferredStyle: .alert)
                let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: kDeleteEditingVPN), object: nil)
                    DispatchQueue.main.async {
                        let _ = self.navigationController?.popViewController(animated: true)
                    }
                })
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

                alertController.addAction(cancelAction)
                alertController.addAction(deleteAction)

                self.present(alertController, animated: true, completion: nil)

            } else {
                view.endEditing(true)
                NotificationCenter.default.addObserver(self, selector: #selector(ConfigureViewController.didExtractedQRCode(notification:)), name: NSNotification.Name(rawValue: kQRCodeExtracted), object: nil)
                performSegue(withIdentifier: "QRCodeScan", sender: nil)
            }
        } else {
            showQRImage()
        }
    }

    /*
     // Override to support conditional editing of the table view.
     override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */

    /*
     // Override to support editing the table view.
     override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
     if editingStyle == .Delete {
     // Delete the row from the data source
     tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
     } else if editingStyle == .Insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */

    /*
     // Override to support rearranging the table view.
     override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
     
     }
     */

    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */

    @IBAction func DoneTapped(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kSaveVPN), object: nil, userInfo: ["proxyConfig": proxyConfig])
        let _ = navigationController?.popViewController(animated: true)
    }

    func updateSelectedResult(_ item: String, selected: String) {
//        print("\(item) \(selected)")
        proxyConfig.setSelection(item, selected: selected)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "selectInputDetail" {
            let destination = segue.destination as! SelectInputViewController

            let item = sender as! String

            destination.delegate = self
            destination.item = item
            destination.selected = proxyConfig.getValue(byItem: item) ?? ""
            let (preset, custom) = proxyConfig.getAvailableOptions(byItem: item)!
            destination.presetSelections = preset
            destination.customSelection = custom

        }
    }
}
