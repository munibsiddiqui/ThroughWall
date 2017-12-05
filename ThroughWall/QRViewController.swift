//
//  QRViewController.swift
//  ThroughWall
//
//  Created by Bingo on 11/05/2017.
//  Copyright © 2017 Wu Bin. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation
import CocoaLumberjack

class QRViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, AVCaptureMetadataOutputObjectsDelegate {

    let imagePicker = customizeUIImagePickerController()
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var result = "" {
        didSet{
            DispatchQueue.main.async {
                let _ = self.navigationController?.popViewController(animated: true)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        imagePicker.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        imagePicker.navigationBar.tintColor = UIColor.white
        imagePicker.navigationBar.isTranslucent = false
        imagePicker.navigationBar.setBackgroundImage(image(fromColor: topUIColor), for: .any, barMetrics: .default)
        imagePicker.navigationBar.shadowImage = UIImage()
        imagePicker.delegate = self

        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)

        do {
            let input = try AVCaptureDeviceInput.init(device: captureDevice!)
            // Initialize the captureSession object.
            captureSession = AVCaptureSession()
            // Set the input device on the capture session.
            captureSession?.addInput(input)
        } catch {
             DDLogError("\(error.localizedDescription)")
            return
        }

        // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession?.addOutput(captureMetadataOutput)

        // Set delegate and use the default dispatch queue to execute the call back
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)

        // Start video capture.
        captureSession?.startRunning()

        // Move the message label to the top view
        //        view.bringSubview(toFront: messageLabel)


        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        qrCodeFrameView?.layer.borderColor = UIColor.green.cgColor
        qrCodeFrameView?.layer.borderWidth = 2
        view.addSubview(qrCodeFrameView!)
        view.bringSubview(toFront: qrCodeFrameView!)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if result == "" {
            return
        }
        let notifcation = Notification(name: Notification.Name(rawValue: kQRCodeExtracted), object: nil, userInfo: ["string" : result])
        NotificationCenter.default.post(notifcation)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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
    
    
    @IBAction func chooseFromGallery(_ sender: UIBarButtonItem) {
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        
        present(imagePicker, animated: true, completion: nil)
        
    }


    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        let qrImg = info[UIImagePickerControllerOriginalImage] as! UIImage
        let detector: CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let ciimg: CIImage = CIImage(image: qrImg)!
        let features = detector.features(in: ciimg)

        if features.count == 0 {
            let alertController = UIAlertController(title: "Extract QRCode Failed", message: "No QRCode detected", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            
            alertController.addAction(okAction)
            DispatchQueue.main.async {
                self.present(alertController, animated: true, completion: nil)
            }
        }
        
        for feature in features as! [CIQRCodeFeature] {
            result = feature.messageString!
            
            
            dismiss(animated: true, completion: nil)
            return
        }

        dismiss(animated: true, completion: nil)
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

//    func metadataOutput(AVCaptureMetadataOutput, didOutput: [AVMetadataObject], from: AVCaptureConnection) {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
//    func metadataOutput(captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.

        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            //            messageLabel.text = "No QR code is detected"
            return
        }

        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject

        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj) as! AVMetadataMachineReadableCodeObject
            qrCodeFrameView?.frame = barCodeObject.bounds;

            if metadataObj.stringValue != nil {
                result = metadataObj.stringValue!
            }
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

class customizeUIImagePickerController: UIImagePickerController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
}
