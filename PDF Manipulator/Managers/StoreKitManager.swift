//
//  StoreKitManager.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/3/22.
//

import UIKit
import StoreKit

private extension SKProduct {
    var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        return formatter.string(from: price)!
    }
}

final class StoreKitManager: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    static let purchaseStateChanged = Notification.Name(rawValue: "purchaseStateChangedNotification")
    
    enum InAppPurchaseProduct: String, CaseIterable {
        case goPro = "com.realnotions.pdfmanipulator.inapppurchase.gopro"
        
        var productIdentifier: String {
            self.rawValue
        }
        
        enum PurchaseState: Int {
            case unknown = 0
            case deferred
            case purchased
        }
        
        private var purchaseStateUserDefaultsKey: String {
            "InAppPurchaseProduct." + self.productIdentifier
        }

        fileprivate(set) var purchaseState: PurchaseState {
            get {
                PurchaseState(rawValue: UserDefaults.standard.integer(forKey: self.purchaseStateUserDefaultsKey)) ?? .unknown
            }
            
            nonmutating set {
                let oldState = self.purchaseState
                
                UserDefaults.standard.set(newValue.rawValue, forKey: self.purchaseStateUserDefaultsKey)
                UserDefaults.standard.synchronize()
                
                if oldState != newValue {
                    NotificationCenter.default.post(name: StoreKitManager.purchaseStateChanged, object: self)
                }
            }
        }
        
        var price: String {
            (StoreKitManager.sharedInstance.products.first {
                $0.productIdentifier == self.productIdentifier
            })?.localizedPrice ?? ""
        }
        
        var description: String {
            (StoreKitManager.sharedInstance.products.first {
                $0.productIdentifier == self.productIdentifier
            })?.localizedDescription ?? ""
        }
        
        var title: String {
            (StoreKitManager.sharedInstance.products.first {
                $0.productIdentifier == self.productIdentifier
            })?.localizedTitle ?? ""
        }
    }
    
    @objc static let sharedInstance = StoreKitManager()
    
    private var productRequest: SKProductsRequest?
    private var products = [SKProduct]()
    private var fetchProductsContinuation: CheckedContinuation<Void, Never>?
    private var productIDAndPurchaseProductContinuation: (String, CheckedContinuation<Void, Never>)?
    private var restoreTransactionsContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
    }
    
    static var canMakePayments: Bool {
        SKPaymentQueue.canMakePayments()
    }
    
    func register() {
        SKPaymentQueue.default().add(self)
        
        Task {
            await self.fetchProducts()

            // Restore in-app purchases at startup.
            for await verificationResult in Transaction.currentEntitlements {
                if case .verified(let transaction) = verificationResult {
                    InAppPurchaseProduct(rawValue: transaction.productID)?.purchaseState = .purchased
                }
            }
        }
    }
    
    @objc func unregister() {
        SKPaymentQueue.default().remove(self)
    }
        
    private func fetchProducts() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.fetchProductsContinuation = continuation
            
            self.productRequest = SKProductsRequest(productIdentifiers: Set(InAppPurchaseProduct.allCases.map { $0.productIdentifier }))
            self.productRequest?.delegate = self
            self.productRequest?.start()
        }
    }
    
    func purchase(product: InAppPurchaseProduct) async {
        guard let product = (self.products.first {
            $0.productIdentifier == product.productIdentifier
        }) else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.productIDAndPurchaseProductContinuation = (product.productIdentifier, continuation)
            
            let payment = SKMutablePayment(product: product)
            SKPaymentQueue.default().add(payment)
        }
    }
    
    func restoreAllProductsPurchaseState() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.restoreTransactionsContinuation = continuation
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }
    
    // MARK: - SKProductsRequestDelegate methods
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.productRequest = nil

        DispatchQueue.main.async {
            self.products = response.products

            self.fetchProductsContinuation?.resume()
            self.fetchProductsContinuation = nil
        }
    }
    
    // MARK: - SKPaymentTransactionObserver methods
    func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue) {
        // When the store front changes, fetch the products again so that the price of the IAP can be shown in now changed currency.
        Task {
            await self.fetchProducts()
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                continue
                                
            case .deferred:
                self.setProductPurchaseState(productIdentifier: transaction.payment.productIdentifier, purchaseState: .deferred)

            case .purchased:
                self.setProductPurchaseState(productIdentifier: transaction.payment.productIdentifier, purchaseState: .purchased)
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .failed:
                DispatchQueue.main.async {
                    let productIdentifier = transaction.payment.productIdentifier
                    if InAppPurchaseProduct(rawValue: productIdentifier)?.purchaseState == .deferred {
                        self.setProductPurchaseState(productIdentifier: productIdentifier, purchaseState: .unknown)
                    }
                    
                    // Cancel button in the payment sheet tapped. Don't show error message.
                    if (transaction.error as? SKError)?.errorCode == SKError.Code.paymentCancelled.rawValue {
                        return
                    }
                    
                    let scene = (UIApplication.shared.openSessions.first {
                        $0.configuration.name == "Default Configuration"
                    })!.scene as! UIWindowScene
                    UIAlertController.show(message: transaction.error?.localizedDescription, defaultButtonTitle: NSLocalizedString("generalOK", comment: ""), scene: scene)
                }

                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .restored:
                self.setProductPurchaseState(productIdentifier: transaction.payment.productIdentifier, purchaseState: .purchased)
                SKPaymentQueue.default().finishTransaction(transaction)
                
            @unknown default:
                break
            }
            
            if self.productIDAndPurchaseProductContinuation?.0 == transaction.payment.productIdentifier {
                self.productIDAndPurchaseProductContinuation?.1.resume()
                self.productIDAndPurchaseProductContinuation = nil
            }
        }
    }
    
    private func setProductPurchaseState(productIdentifier: String, purchaseState: InAppPurchaseProduct.PurchaseState) {
        DispatchQueue.main.async {
            InAppPurchaseProduct(rawValue: productIdentifier)?.purchaseState = purchaseState
        }
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        self.restoreTransactionsContinuation?.resume()
        self.restoreTransactionsContinuation = nil
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        self.restoreTransactionsContinuation?.resume()
        self.restoreTransactionsContinuation = nil
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
        if productIdentifiers.contains(InAppPurchaseProduct.goPro.productIdentifier) {
            
        }
    }
}
