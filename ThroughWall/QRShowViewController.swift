//
//  QRShowViewController.swift
//  ThroughWall
//
//  Created by Bin on 12/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit

class QRShowViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    var QRCImage = UIImage()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        imageView.image = QRCImage
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func savePhoto(_ sender: UIButton) {
        UIImageWriteToSavedPhotosAlbum(QRCImage, self,#selector(image(image:didFinishSavingWithError:contextInfo:)), nil)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("touched")
        dismiss(animated: true, completion: nil)
    }
    
    func image(image:UIImage,didFinishSavingWithError error:NSError?,contextInfo:AnyObject) {
        
        if error != nil {
            let alertController = UIAlertController(title: "Failed", message: "Failed to save QRCode", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .destructive, handler: nil)
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        } else {
            let alertController = UIAlertController(title: "Saved", message: "QRCode saved", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
            })
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
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
