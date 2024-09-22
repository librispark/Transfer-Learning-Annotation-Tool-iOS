//
//  BottomRoundedView.swift
//  LSTFL_Gather
//
//  Created by Jeremy Feldman on 4/14/19.
//  Copyright © 2019 user. All rights reserved.
//

import Foundation
import AWSCognitoIdentityProvider
import UIKit

class BottomRoundedView: UIView {

    var response: AWSCognitoIdentityUserGetDetailsResponse?
    var user: AWSCognitoIdentityUser?
    var pool: AWSCognitoIdentityUserPool?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.roundCorners([.bottomLeft, .bottomRight], radius: 20)
        
//        self.pool = AWSCognitoIdentityUserPool(forKey: AWSCognitoUserPoolsSignInProviderKey)
//        if (self.user == nil) {
//            self.user = self.pool?.currentUser()
//        }
//        self.refresh()
    }
    
    func signOut() {
        self.user?.signOut()
        self.response = nil
        self.refresh()
    }
    
    func refresh() {
        self.user?.getDetails().continueOnSuccessWith { (task) -> AnyObject? in
            DispatchQueue.main.async(execute: {
                self.response = task.result
            })
            return nil
        }
    }
    
    @IBAction func logoutButtonAction(_ sender: Any) {
        print("logout button pressed")
//        self.signOut()
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
