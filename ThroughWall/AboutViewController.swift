//
//  AboutViewController.swift
//  ThroughWall
//
//  Created by Bin on 08/06/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var labelVersion: UILabel!
    @IBOutlet weak var infoContnet: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = veryLightGrayUIColor
        labelVersion.text = ""
//        infoContnet.text = ""
        infoContnet.backgroundColor = veryLightGrayUIColor
        infoContnet.isHidden = true
        setTopArear()
        
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            labelVersion.text = "V" + version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            let tmpStr = labelVersion.text ?? ""
            labelVersion.text = tmpStr + " Build:" + build
        }

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
