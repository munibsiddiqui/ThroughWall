
//  AboutViewController.swift
//  ThroughWall
//
//  Created by Bin on 08/06/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = veryLightGrayUIColor

        setTopArear()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = veryLightGrayUIColor
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    func setTopArear() {
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        navigationController?.navigationBar.tintColor = UIColor.white
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationItem.title = "About"
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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


extension AboutViewController: UITableViewDelegate, UITableViewDataSource {
    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 {
            return 0
        }
        return 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return getCellforVersionSection(withIndexPath: indexPath)
        default:
            return getFollowMeSection(withIndexPath: indexPath)
        }
    }

    func getCellforVersionSection(withIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Version"
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                cell.detailTextLabel?.text = version
            }
        } else {
            cell.textLabel?.text = "Build"
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                cell.detailTextLabel?.text = build
            }
        }
        return cell

    }

    func getFollowMeSection(withIndexPath indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Follow on Twitter"
            cell.imageView?.image = UIImage(named: "Twitter")
        } else {
            cell.textLabel?.text = "Telegram"
            cell.imageView?.image = UIImage(named: "Telegram")
        }

        return cell
    }


    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 18))
        view.backgroundColor = veryLightGrayUIColor
        return view
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                FollowOnSocial.followOnTwitter(withAccount: "ChiselProxy")
            }else {
                FollowOnSocial.chatOnTelegram(withAccount: "FatalEr")
            }
        }
    }
    
}
