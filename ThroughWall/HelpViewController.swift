//
//  HelpViewController.swift
//  ThroughWall
//
//  Created by Bin on 09/12/2016.
//  Copyright © 2016 Wu Bin. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {

    @IBOutlet weak var urlLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(HelpViewController.labelTapped(_:)))
        urlLabel.addGestureRecognizer(tapGesture)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func labelTapped(_ sender: UITapGestureRecognizer) {
        let url = urlLabel.text!
        let targetURL = URL.init(string: url)
        let application=UIApplication.shared
        application.open(targetURL!, options: [:], completionHandler: nil)
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
