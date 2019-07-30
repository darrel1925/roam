//
//  CheckOutController.swift
//  Roam
//
//  Created by Darrel Muonekwu on 7/27/19.
//  Copyright © 2019 Darrel Muonekwu. All rights reserved.
//

import UIKit
import Stripe
import FirebaseFunctions

class CheckOutController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var paymentMethodButton: UIButton!
    @IBOutlet weak var subtotalLabel: UILabel!
    @IBOutlet weak var processingFeeLabel: UILabel!
    @IBOutlet weak var deliveryFeeLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var paymentContext: STPPaymentContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setUpTableView()
        setUpPaymentInfo()
        setUpStripeConfig()
    }
    
    func setUpTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func setUpPaymentInfo() {
        subtotalLabel.text = StripeCart.penniesToFormattedCurrency(numberInPennies: StripeCart.subtotal)
        processingFeeLabel.text = StripeCart.penniesToFormattedCurrency(numberInPennies:  StripeCart.processingFees)
        deliveryFeeLabel.text = StripeCart.penniesToFormattedCurrency(numberInPennies:  StripeCart.deliveryFee)
        totalLabel.text = StripeCart.penniesToFormattedCurrency(numberInPennies:  StripeCart.total)
    }

    
    func setUpStripeConfig() {
        
        
        let config = STPPaymentConfiguration.shared()
        
        config.requiredBillingAddressFields = .none
        
        // this class will retrieve and update the customer object using the ephemeral key that it gets from the cloud function that is call from the StripeApi
        
        let customerContext = STPCustomerContext(keyProvider: StripeApi)
        
        paymentContext = STPPaymentContext(customerContext: customerContext, configuration: config, theme: .default())
        paymentContext.paymentAmount = StripeCart.total
        paymentContext.delegate = self
        paymentContext.hostViewController = self
    }
    
    @IBAction func paymentMethodClicked(_ sender: Any) {
        paymentContext.presentPaymentOptionsViewController()
    }
    
    @IBAction func placeOrderClicked(_ sender: Any) {
        activityIndicator.startAnimating()
        paymentContext.requestPayment()
        
        }
    
    @IBAction func backButtonClicked(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension CheckOutController: STPPaymentContextDelegate {
    func paymentContextDidChange(_ paymentContext: STPPaymentContext) {
        activityIndicator.stopAnimating()
        // updating selected payment method text
        if let paymentMethod = paymentContext.selectedPaymentOption{
            paymentMethodButton.setTitle(paymentMethod.label, for: .normal)
        
            print("got payment method bc it changed")
        }
        else {
            paymentMethodButton.setTitle("Select Method", for: .normal)
            print("could not get payment method afteer change")
        }
    }
    
    // called if there was an error getting payment info from customer
    func paymentContext(_ paymentContext: STPPaymentContext, didFailToLoadWithError error: Error) {
        activityIndicator.stopAnimating()
        let alertContoller = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        
        let retry = UIAlertAction(title: "Retry", style: .default, handler: {(action) in
            self.paymentContext.retryLoading()
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {(action) in
            self.dismiss(animated: true, completion: nil)
        })
        
        alertContoller.addAction(cancel)
        alertContoller.addAction(retry)
        present(alertContoller, animated: true, completion: nil)
    }
    
    func paymentContext(_ paymentContext: STPPaymentContext, didCreatePaymentResult paymentResult: STPPaymentResult, completion: @escaping STPErrorBlock) {

        let idempotency = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        print("\n")
        print(UserService.user.stripeId)
        print(StripeCart.total)
        print(idempotency)
        
        let data: [String: Any] = [
            "total": StripeCart.total,
            "customer_id": UserService.user.stripeId,
            "idempotency": idempotency,
        ]
        
        // call cloud function to make request to make payment
        Functions.functions().httpsCallable("createCharge").call(data) { (result, error) in
            if let error = error {
                debugPrint(error.localizedDescription)
                // present alert saying Unable to make charge
                completion(error)
                return
            }
            
            StripeCart.clearCart()
            self.tableView.reloadData()
            self.setUpPaymentInfo()
            completion(nil)
        }
        
    }
    
    func paymentContext(_ paymentContext: STPPaymentContext, didFinishWith status: STPPaymentStatus, error: Error?) {
        let title: String
        let message: String
        activityIndicator.stopAnimating()

        switch status {
        case .error:
            title = "Error"
            message = error?.localizedDescription ?? "unable to get error message in cart"
            print("was error")
            break
        case .success:
            title = "Success!"
            message = "Thank you for your purchase"
            print("was successful")
            break
        case .userCancellation:
            print("user cancel")
            return
        }
            
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let okay = UIAlertAction(title: "Okay", style: .default, handler: {(action) in
            self.dismiss(animated: true, completion: nil)
        })
        
        alertController.addAction(okay)
        self.present(alertController, animated: true)
        
    }
    
}


extension CheckOutController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return StripeCart.cartItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let item = StripeCart.cartItems[row]
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ShoppingCartCell") as? ShoppingCartCell {
            cell.numItemsLabel.text = "1"
            cell.titleLabel.text = item.name
            cell.itemDescriptionLabel.text = item.description
            cell.costLabel.text = "$" + String(format: "%.2f", item.price)
            return cell
        }
        print("ERROR: trouble loading cell in cart")
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let product = StripeCart.cartItems[indexPath.row]
            StripeCart.removeItemFromCart(item: product)
            
            paymentContext.paymentAmount = StripeCart.total
            
            self.setUpTableView()
            self.tableView.reloadData()
        }
    }
    
}
