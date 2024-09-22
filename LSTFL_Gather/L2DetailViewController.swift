//
//  L2DetailViewController.swift
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 4/11/19.
//  Copyright © 2019 user. All rights reserved.
//

import UIKit

class L2DetailViewController: UIViewController {
    
    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var showHideLabels: UISegmentedControl!
    
    var docDirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    let viewPpseSelection: [String] = []
    var viewPpseSelectionIndex: Int?
    var viewImageFilename: String?
    var annotObj: [Dictionary<Substring, Substring>]?  // we now have all the annotations for this image...
    var labeledImage = UIImage()
    var defaultImage = UIImage()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        print("viewPpseSelectionIndex: \(viewPpseSelectionIndex ?? 0)")
        if let filename = viewImageFilename {
            let imageURL = docDirPaths.appendingPathComponent(filename)
            if let foundImage = UIImage(contentsOfFile: imageURL) {
                defaultImage = foundImage
                if let annots = annotObj {
                    labeledImage = drawRectsOnImage(image: foundImage, annots: annots)
                    mainImageView.image = labeledImage
                } else {
                    mainImageView.image = foundImage
                }
            }
        }
    }
    
    func drawRectsOnImage(image: UIImage, annots: [Dictionary<Substring, Substring>]) -> UIImage {
//        let imageSize = image.size
//        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        // Create a context of the starting image size and set it as the current one
        UIGraphicsBeginImageContext(image.size)
        
        // Draw the starting image in the current context as background
        image.draw(at: CGPoint.zero)
        
        // Get the current context
        let context = UIGraphicsGetCurrentContext()!
        
        for (index, annot) in annots.enumerated() {
            print("key: \(index), value: \(annot)")
            let classLabel = annot["class"]!
            let xmin = (annot["xmin"]! as NSString).integerValue
            let ymin = (annot["ymin"]! as NSString).integerValue
            let rectWidth = (annot["xmax"]! as NSString).integerValue - xmin
            let rectHeight = (annot["ymax"]! as NSString).integerValue - ymin
            
            let rectangle = CGRect(x: xmin, y: ymin, width: rectWidth, height: rectHeight)
            context.setFillColor(UIColor.clear.cgColor)
            context.setStrokeColor(UIColor.green.cgColor)
            context.setLineWidth(2)
            context.addRect(rectangle)
            context.drawPath(using: .fillStroke)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key : Any] = [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 30.0),
                .foregroundColor: UIColor.green
            ]
            
            let classText = String(classLabel)
            let attributedString = NSAttributedString(string: classText, attributes: attributes)
            
            let stringRect = CGRect(x: xmin, y: ymin-35-5, width: rectWidth, height: 35)
            attributedString.draw(in: stringRect)
        }
        
        // Save the context as a new UIImage
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return img!
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func showHideLabelsAction(_ sender: Any) {
        print("control: \(showHideLabels.selectedSegmentIndex)")
        if showHideLabels.selectedSegmentIndex == 1 {
            print("show boxes...")
            mainImageView.image = defaultImage
        } else {
            print("hide boxes...")
            mainImageView.image = labeledImage
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
