//
//  ReceiptOCRPreviewViewController.swift
//  ImageWithRect
//
//  Created by Ankit on 12/02/24.
//

import UIKit

class OCRNormalizedRect{
    let width : CGFloat
    let top : CGFloat
    let height : CGFloat
    let left : CGFloat
    
    init(_ width: CGFloat, _ top: CGFloat, _ height: CGFloat, _ left: CGFloat) {
        self.width = width
        self.top = top
        self.height = height
        self.left = left
    }
    
    func convertNormalizedRectsToCGRects(imageViewHeight: CGFloat, imageViewWidth: CGFloat) -> CGRect {
        return CGRect(
            x: left * imageViewWidth,
            y: top * imageViewHeight,
            width: width * imageViewWidth,
            height: height * imageViewHeight
        )
    }
}

class OcrNormalizedRectData{
    enum OCRDataType : String {
        case Amount = "amounts"
        case ReceiptNumber = "receipt_numbers"
        case ReceiptDate = "dates"
        case Others = "others"
        
        func getColorRep() -> UIColor {
            switch self {
            case .Amount:
                return .blue
            case .ReceiptNumber:
                return .orange
            case .ReceiptDate:
                return.green
            case .Others:
                return .orange
            }
        }
    }
    
    private var raw : [String : Any]
    public private (set) var ocrDataType : OCRDataType
    init( raw : [String : Any], ocrDataType: OCRDataType) {
        self.raw = raw
        self.ocrDataType = ocrDataType
    }
    
    lazy var rawKey: String = {
        let (firstKey, firstValue) = raw.first!
        return firstKey
    }()
    
    lazy var normalizedRectangle: OCRNormalizedRect? = {
        
        if
            let ocrDict = raw[rawKey] as? [String : Any],
            let geomety = ocrDict["geometry"] as? [ String : Any],
            let width = geomety["Width"] as? CGFloat,
            let top = geomety["Top"] as? CGFloat,
            let height = geomety["Height"] as? CGFloat,
            let left = geomety["Left"] as? CGFloat{
            return OCRNormalizedRect(width, top, height, left)
        }else{
            return nil
        }
    }()
    
}

class ReceiptOCRPreviewViewController: UIViewController {
    @IBOutlet var container: UIView!
    var imageView: UIImageView!
    var scrollView: UIScrollView!
    var rectangleView: UIView!
    var activityIndicator: UIActivityIndicatorView!
    var imageURL: URL?
    var rectanglesData: [OcrNormalizedRectData] = [] // Array of normalized rectangles: [x, y, width, height]
    var zoomScale: CGFloat = 1.0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the scroll view
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        container.addSubview(scrollView)
        
        // Set up the image view
        imageView = UIImageView(frame: scrollView.bounds)
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        
        // Set up the rectangle view
        rectangleView = UIView(frame: imageView.bounds)
        rectangleView.isUserInteractionEnabled = false
        imageView.addSubview(rectangleView)
        
        // Set up activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        container.addSubview(activityIndicator)
        
        // Do any additional setup after loading the view.
        if let jsonURL = Bundle.main.url(forResource: "sample2", withExtension: "json") {
            pasrseJson(from: jsonURL)
        }
    }
    
    @IBAction private func dismissTapped(){
        self.dismiss(animated: true)
    }
    
    private func addAmounts(_ amountsOCRData : [[String : Any]]){
        for amountOCRData in amountsOCRData {
            rectanglesData.append(OcrNormalizedRectData(raw: amountOCRData, ocrDataType: .Amount))
        }
    }
    
    private func addReceiptNumbers(_ receiptNumbersOCRData : [[String : Any]]){
        for receiptNumberOCRData in receiptNumbersOCRData {
            rectanglesData.append(OcrNormalizedRectData(raw: receiptNumberOCRData, ocrDataType: .ReceiptNumber))
        }
    }
    
    private func addReceiptDates(_ receiptDatesOCRData : [[String : Any]]){
        for receiptDateOCRData in receiptDatesOCRData {
            rectanglesData.append(OcrNormalizedRectData(raw: receiptDateOCRData, ocrDataType: .ReceiptDate))
        }
    }
    
    private func addOthers(_ othersOCRData : [[String : Any]]){
        for otherOCRData in othersOCRData {
            rectanglesData.append(OcrNormalizedRectData(raw: otherOCRData, ocrDataType: .Others))
        }
    }
    
    
    private func loadNormalizedRectangles(_ ocrData: [String : Any]){
        debugPrint("<<<<<< loadNormalizedRectangles")
        if let amounts = ocrData ["amounts"] as? [[String : Any]]{
            self.addAmounts(amounts)
        }
        if let receiptNumbers = ocrData ["receipt_numbers"] as? [[String : Any]]{
            self.addReceiptNumbers(receiptNumbers)
        }
        if let receiptDates = ocrData ["dates"] as? [[String : Any]]{
            self.addReceiptDates(receiptDates)
        }
        if let others = ocrData ["others"] as? [[String : Any]]{
            self.addOthers(others)
        }
    }
    
    private func pasrseJson(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            //find image url
            if let urlString = json?["upload"] as? String,
               let imageURL = URL(string: "https://tom.skordev.com\(urlString)") {
                print(imageURL)
                self.imageURL = imageURL
                downloadImage(from: imageURL)
            } else {
                print("Invalid JSON format or imageURL key not found.")
            }
            
            //load rectangles
            if let ocrData =  json?["ocr_data_json"] as? [String : Any]{
                loadNormalizedRectangles(ocrData)
            }
            
        } catch {
            print("Error reading JSON file:", error.localizedDescription)
        }
    }
    
    func downloadImage(from url: URL) {
        // Show activity indicator
        activityIndicator.startAnimating()
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Hide activity indicator
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("Failed to download image:", error?.localizedDescription ?? "Unknown error")
                return
            }
            
            DispatchQueue.main.async {
                self.imageView.image = image
                self.redrawRectangles()
            }
        }.resume()
    }
    
    private func redrawRectangles() {
        guard let image = imageView.image else { return }
        
        // Clear previously drawn rectangles
        rectangleView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // Calculate scale considering aspect fit
        let imageSize = image.size
        let viewSize = imageView.bounds.size
        let scaleWidth = viewSize.width / imageSize.width
        let scaleHeight = viewSize.height / imageSize.height
        let scale = min(scaleWidth, scaleHeight)
        let offsetX = (viewSize.width - imageSize.width * scale) / 2
        let offsetY = (viewSize.height - imageSize.height * scale) / 2
        
        // Redraw rectangles
        debugPrint("redraw rectangles")
        for rectData in rectanglesData {
            if let normalizedRect = rectData.normalizedRectangle{
                let rect =  normalizedRect.convertNormalizedRectsToCGRects(
                    imageViewHeight: imageSize.height,
                    imageViewWidth: imageSize.width)
                let scaledRect = CGRect(
                    x: rect.origin.x * scale + offsetX,
                    y: rect.origin.y * scale + offsetY,
                    width: rect.size.width * scale,
                    height: rect.size.height * scale
                )
                let layer = CALayer()
                
                layer.borderColor = rectData.ocrDataType.getColorRep().cgColor
                layer.borderWidth = 2.0
                layer.frame = scaledRect
                rectangleView.layer.addSublayer(layer)
            }
        }
    }
}


extension ReceiptOCRPreviewViewController : UIScrollViewDelegate{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        redrawRectangles()
    }
}
