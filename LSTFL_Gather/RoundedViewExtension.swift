//
//  RoundedViewExtension.swift
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 4/14/19.
//  Copyright © 2019 user. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }
}
