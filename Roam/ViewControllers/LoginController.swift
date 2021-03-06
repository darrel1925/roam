//
//  LoginController.swift
//  Roam
//
//  Created by Darrel Muonekwu on 7/27/19.
//  Copyright © 2019 Darrel Muonekwu. All rights reserved.
//

import UIKit
import Firebase

class LoginController: UIViewController {
    
    func setTextLine(){
    emailField.setBottomBorder()
    emailField.setPadding()
    passwordField.setBottomBorder()
    passwordField.setPadding()
    
    
    }

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {

        super.viewDidLoad()
        setTextLine()

    }
    
    @IBAction func loginClicked(_ sender: Any) {
        activityIndicator.startAnimating()
        let email = emailField.text!
        let password = passwordField.text!
        
        UserService.loggedInAsCustomer = true
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] user, error in
            
            if let error = error {
                self?.displayError(error: error)
                debugPrint(error.localizedDescription)
                self?.activityIndicator.stopAnimating()
                return
            }
            
            print("Login was successful")
            self?.activityIndicator.stopAnimating()
        }
    }
    
    @IBAction func logInForRoamer(_ sender: Any) {
        activityIndicator.startAnimating()
        let email = emailField.text!
        let password = passwordField.text!
        
        UserService.loggedInAsCustomer = false
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] user, error in
            
            if let error = error {
                self?.displayError(error: error)
                debugPrint(error.localizedDescription)
                self?.activityIndicator.stopAnimating()
                return
            }
            
            print("Roamer login was successful")
            self?.setIsCustomerParam(email: email)
            self?.activityIndicator.stopAnimating()

  
        }
    }
    
    func setIsCustomerParam(email: String) {
        UserService.dispatchGroup.enter()
        // Add a new document in collection "Users"
        let db = Firestore.firestore()
        let newUserRef = db.collection(Collections.Users).document(email)
        var data: [String: Any]!
        if UserService.loggedInAsCustomer {
            data = ["isCustomer": "true"]
        }
        else {
            data = ["isCustomer": "false"]
        }
        
        newUserRef.setData(data, merge: true) { error in
            if let error = error {
                print("Error writing document: \(error)")
                
            } else {
                print("isCustomer is \(String(UserService.loggedInAsCustomer))!")
            }
            UserService.dispatchGroup.customLeave()
        }
    }

    @IBAction func backButtonClicked(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        // navigationController?.popViewController(animated: true)
    }
    
    @IBAction func forgotPasswordClicked(_ sender: Any) {
        let forgotPassVC = ForgotPasswordController()
        
        forgotPassVC.modalTransitionStyle = .crossDissolve
        forgotPassVC.modalPresentationStyle = .overCurrentContext
        present(forgotPassVC, animated: true, completion: nil)
    }
    
}
