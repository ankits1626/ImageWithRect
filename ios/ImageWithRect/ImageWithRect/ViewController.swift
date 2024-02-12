//
//  ViewController.swift
//  ImageWithRect
//
//  Created by Ankit on 12/02/24.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction private func showreciptOCRPreview(){
        let vc  = ReceiptOCRPreviewViewController(nibName: "ReceiptOCRPreviewViewController", bundle: nil)
        vc.modalPresentationStyle = .fullScreen 
        self.present(vc, animated: true)
    }
}

