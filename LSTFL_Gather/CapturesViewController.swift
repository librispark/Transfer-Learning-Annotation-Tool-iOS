//
//  CapturesViewController.swift
//  CollectionView
//
//  Created by Jeremy Feldman on 3/31/19.
//  Copyright © 2019 user. All rights reserved.
//

import UIKit

@objc protocol CapturesViewControllerDelegate: AnyObject {
    func modalDidClose()
}

class MyCell: UICollectionViewCell {
    @IBOutlet weak var textNumber: UILabel!
    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var textLabel: UILabel!
}

class CapturesViewController: UIViewController {

    var docDirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    var annotsDirPath = ""
    var annotsFilename = "captures_annotations.csv"
    var annotsObj: [Substring: Array<Dictionary<Substring, Substring>>] = [:]
    var selectedImageAtIndexName = ""
    var selectedAnnotAtIndexObj: [Dictionary<Substring, Substring>] = []
    var annotsFileCsvRowArray: [String] = []
    var labelsArry: Array<Substring> = [] // basically: "filename,width,height,class,xmin,ymin,xmax,ymax".split(",")
    
    @IBOutlet weak var collectionView: UICollectionView!
  
    @objc weak var delegate: CapturesViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        annotsDirPath = docDirPaths.appendingPathComponent(annotsFilename)
        guard let annots = FileLineReader(path: annotsDirPath) else {
            // shouldn't ever happen, should be created in ViewController.mm (app entrypoint)
            print("can't find captures_annotations.csv")
            return; // cannot open file
        }
        
        annotsFileCsvRowArray = []
        for annot in annots {
            annotsFileCsvRowArray.append(annot)
            let annotTrim = annot.trimmingCharacters(in: .whitespacesAndNewlines)
            if(annotTrim == "filename,width,height,class,xmin,ymin,xmax,ymax") {
                self.labelsArry = annotTrim.split(separator: ",")
            } else {
                let annotValsArry = annotTrim.split(separator: ",")
                if(self.labelsArry.count == annotValsArry.count) {
                    if let annotsObjVal = annotsObj[annotValsArry[0]] {
                        annotsObj[annotValsArry[0]]?.append(Dictionary(uniqueKeysWithValues: zip(self.labelsArry, annotValsArry)))
                    } else {
                        annotsObj[annotValsArry[0]] = [Dictionary(uniqueKeysWithValues: zip(self.labelsArry, annotValsArry))]
                    }
                } else {
                    print("didn't find the csv header, shouldn't happen..")
                }
            }
        }
        
        print("annotsObj.count: \(annotsFileCsvRowArray.count)")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let sizeSide = (self.collectionView.bounds.width/2) - 25
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: sizeSide, height: sizeSide)
        }
    }
  
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Notify the delegate when the modal is dismissed
        if self.isBeingDismissed {
            delegate?.modalDidClose()
        }
    }
    
    func selectedImageAtIndex(index: Int) -> Void {
        let alert = UIAlertController(title: "Selected Image \(index + 1)", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "View Image \(index + 1)", style: .default , handler:{ (UIAlertAction)in
            print("User click View button")
            self.selectedImageAtIndexName = String(self.annotsFileCsvRowArray[index + 1].split(separator: ",")[0])
            self.selectedAnnotAtIndexObj = self.annotsObj[Substring(self.selectedImageAtIndexName)]!
            self.performSegue(withIdentifier: "L2Detail", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Re-label Image \(index + 1)", style: .default , handler:{ (UIAlertAction)in
            print("User click Label button")
            let imageName = String(self.annotsFileCsvRowArray[index + 1].split(separator: ",")[0])
            let imageFullLabel = self.annotsObj[Substring(imageName)]![0]["class"]!
            let imageLabel = imageFullLabel.firstIndex(of: ":") == nil ? imageFullLabel : imageFullLabel.split(separator: ":")[1]
            let alertDialog = UIAlertController(title: "Update Label", message: "Replace '\(imageLabel)' with (add below)", preferredStyle: .alert)
            alertDialog.addTextField { (textField) in
                textField.placeholder = "Enter your input here"
            }
            alertDialog.addAction(UIKit.UIAlertAction(title: "Ok", style: .default, handler: { _ in
                if let inputText = alertDialog.textFields?.first?.text {
                    self.replaceRowInAnnotFile(newLabel: inputText, rowNumber: index)
                    self.collectionView.reloadData()
                }
            }))
            alertDialog.addAction(UIKit.UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alertDialog, animated: true)
            
        }))
        alert.addAction(UIAlertAction(title: "Delete Image \(index + 1)", style: .destructive , handler:{ (UIAlertAction)in
            print("User click Delete button")
            
            let alertDialog = UIAlertController(title: "Delete Image \(index + 1)", message: "Press OK to continue.", preferredStyle: .alert)
            alertDialog.addAction(UIKit.UIAlertAction(title: "Ok", style: .default, handler: { _ in
                self.deleteRowInAnnotFile(rowNumber: index)
                self.collectionView.reloadData()
            }))
            alertDialog.addAction(UIKit.UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alertDialog, animated: true)
            
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:{ (UIAlertAction)in
            print("User click Cancel button")
        }))
        self.present(alert, animated: true, completion: {
            print("completion block")
        })
    }

    func writeToAnnotFile(writeString: String) -> Void {
        let content = "\(writeString)\n"
        if let filehandle = FileHandle(forWritingAtPath: annotsDirPath) {
            filehandle.seekToEndOfFile()
            filehandle.write(content.data(using: .utf8)!)
            filehandle.closeFile()
        } else {
            do {
                try content.write(toFile: annotsDirPath, atomically: false, encoding: .utf8)
            } catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                print("failed to write to file...")
            }
        }
    }
    
    func replaceRowInAnnotFile(newLabel: String, rowNumber: Int) -> Void {
        if rowNumber == 0 {
            print("rowNumber 0 / index row, shouldn't happen.")
        }
        print("old row: ", self.annotsFileCsvRowArray[rowNumber + 1]);
        let imageName = String(self.annotsFileCsvRowArray[rowNumber + 1].split(separator: ",")[0])
        let currentFullLabel = self.annotsObj[Substring(imageName)]![0]["class"]!
        let newFullLabel = currentFullLabel.firstIndex(of: ":") == nil ? newLabel : currentFullLabel.split(separator: ":")[0] + ":" + newLabel
        var rowArr = self.annotsFileCsvRowArray[rowNumber + 1].split(separator: ",")
        rowArr[3] = Substring(newFullLabel)
        let newRow = rowArr.joined(separator: ",")
        print("new row: ", newRow)
        
        self.annotsFileCsvRowArray[rowNumber + 1] = newRow
        let annotTrim = newRow.trimmingCharacters(in: .whitespacesAndNewlines)
        let annotValsArry = annotTrim.split(separator: ",")
        annotsObj[annotValsArry[0]] = [Dictionary(uniqueKeysWithValues: zip(self.labelsArry, annotValsArry))]
        
        let updatedFileContent = self.annotsFileCsvRowArray.joined()
        
        do {
            try updatedFileContent.write(toFile: annotsDirPath, atomically: true, encoding: .utf8)
            print("File updated successfully.")
        } catch {
            print("Failed to write to the file: \(error)")
        }
    }
    
    func deleteRowInAnnotFile(rowNumber: Int) -> Void {
        if rowNumber == 0 {
            print("rowNumber 0 / index row, shouldn't happen.")
        }
        let oldRow = self.annotsFileCsvRowArray[rowNumber + 1]
        print("old row: ", self.annotsFileCsvRowArray[rowNumber + 1]);
        let imageName = String(self.annotsFileCsvRowArray[rowNumber + 1].split(separator: ",")[0])
        let currentFullLabel = self.annotsObj[Substring(imageName)]![0]["class"]!

        
        self.annotsFileCsvRowArray.remove(at: rowNumber + 1)
        let annotTrim = oldRow.trimmingCharacters(in: .whitespacesAndNewlines)
        let annotValsArry = annotTrim.split(separator: ",")
        annotsObj.removeValue(forKey: annotValsArry[0])
        
        let updatedFileContent = self.annotsFileCsvRowArray.joined()
        
        do {
            try updatedFileContent.write(toFile: annotsDirPath, atomically: true, encoding: .utf8)
            print("File updated successfully.")
        } catch {
            print("Failed to write to the file: \(error)")
        }
    }
    
    func deleteAllImagesAndResetAnnots() -> Void {
        let docDirPath = docDirPaths.appendingPathComponent("") // captures_annotations.csv
        let fm = FileManager.default
        do {
            let filenames = try fm.contentsOfDirectory(atPath: docDirPath)
            for filename in filenames {
                print("Found \(filename)")
                let filePath = docDirPaths.appendingPathComponent(filename)
                try fm.removeItem(atPath: filePath)
            }
            fm.createFile(atPath: docDirPath, contents: nil, attributes: nil)
            writeToAnnotFile(writeString: "filename,width,height,class,xmin,ymin,xmax,ymax")
            self.dismiss(animated: true, completion: nil)
        } catch {
            // failed to read directory – bad permissions, perhaps?
            print("failed to read directory...")
        }
    }

    func exportFilesAndPresentShareSheet(viewController: UIViewController) {
        let fm = FileManager.default
        guard let baseDirectoryUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        var archiveUrl: URL?
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        
        // Step 1: Zip up the documents directory
        coordinator.coordinate(readingItemAt: baseDirectoryUrl, options: [.forUploading], error: &coordinatorError) { zipUrl in
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                
                let tmpUrl = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: zipUrl, create: true)
                    .appendingPathComponent("annotations_\(timestamp).zip")
                
                try fm.moveItem(at: zipUrl, to: tmpUrl)
                archiveUrl = tmpUrl
            } catch {
                print("Error moving zip file: \(error)")
            }
        }

        // Step 2: Present the share sheet and delete the zip after the share sheet is closed
        if let archiveUrl = archiveUrl {
            // Bring up the share sheet to send the annotations with AirDrop, email, etc.
            let activityViewController = UIActivityViewController(activityItems: [archiveUrl], applicationActivities: nil)
            
            activityViewController.completionWithItemsHandler = { activity, success, items, error in
                do {
                    try fm.removeItem(at: archiveUrl)
                    print("Temporary zip file deleted")
                } catch {
                    print("Error deleting temporary zip file: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                viewController.present(activityViewController, animated: true)
            }
        } else {
            print("Error creating zip file: \(String(describing: coordinatorError))")
        }
    }

    
    @IBAction func closeButtonAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func menuButtonAction(_ sender: Any) {
        let alert = UIAlertController(title: "All Images", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Train Model", style: .default , handler:{ (UIAlertAction)in
            print("User click Label button")
            self.performSegue(withIdentifier: "SmartLabelerDetail", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Export", style: .default , handler:{ (UIAlertAction)in
            print("User click upload button")
            
            let alertDialog = UIAlertController(title: "Export", message: "This will export all images and annotations in a zip.", preferredStyle: .alert)
            alertDialog.addAction(UIKit.UIAlertAction(title: "Ok", style: .default, handler: { _ in
                self.exportFilesAndPresentShareSheet(viewController: self)
            }))
            alertDialog.addAction(UIKit.UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alertDialog, animated: true)
            
        }))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive , handler:{ (UIAlertAction)in
            print("User click Delete button")
            self.deleteAllImagesAndResetAnnots()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:{ (UIAlertAction)in
            print("User click Cancel button")
        }))
        self.present(alert, animated: true, completion: {
            print("completion block")
        })
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "L2Detail" {
            if let l2detail = segue.destination as? L2DetailViewController {
//                destinationVC.exampleStringProperty = "Example"
                l2detail.viewPpseSelectionIndex = 1
                l2detail.viewImageFilename = self.selectedImageAtIndexName
                l2detail.annotObj = self.selectedAnnotAtIndexObj
            }
        }
        
        if segue.identifier == "SmartLabelerDetail" {
            if let smartlabelerdetail = segue.destination as? SmartLabelerDetailViewController {
                
            }
        }
        
    }
}

extension CapturesViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.annotsFileCsvRowArray.count - 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MyCell", for: indexPath) as! MyCell
        
        let row = self.annotsFileCsvRowArray[indexPath.row + 1].split(separator: ",")
        let filename = String(row[0])
        let labelSplit = row[3].split(separator: ":")
        let label = String(labelSplit.count == 2 ? labelSplit[1] : row[3])
        
        let getImagePath = docDirPaths.appendingPathComponent(filename)
        cell.mainImageView.image = UIImage(contentsOfFile: getImagePath)
        cell.textNumber.text = String(indexPath.row + 1)
        cell.textLabel.text = label.count == 0 ? "???" : label
        
        return cell
    }
}

extension CapturesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("indexPath.item: \(indexPath.item)")
        self.selectedImageAtIndex(index: indexPath.item)
    }
}
