//
//  TopRoundedView.swift
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 3/31/19.
//  Copyright © 2019 user. All rights reserved.
//

import UIKit

class TopRoundedView: UIView {

    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.roundCorners([.topLeft, .topRight], radius: 20)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
