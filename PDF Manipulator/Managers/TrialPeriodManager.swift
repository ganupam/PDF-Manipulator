//
//  TrialPeriodManager.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 3/10/23.
//

import Foundation
import Combine
import UIKit

final class TrialPeriodManager {
    private static let trialBeganDateKey = "trialBeganDateKey"
    private static let trialPeriodInDays = 3.0
    static let trialPeriodStateChanged = Notification.Name(rawValue: "trialPeriodStateChangedNotification")
    static let sharedInstance = TrialPeriodManager()
    private let cancellable: AnyCancellable
    
    enum State: Equatable {
        case preTrial
        case trial(Date)
        case trialPeriodExpired
        case pro
    }
    
    private init() {
        self.cancellable = NotificationCenter.default.publisher(for: StoreKitManager.purchaseStateChanged).sink { _ in
            if StoreKitManager.InAppPurchaseProduct.goPro.purchaseState == .purchased {
                NotificationCenter.default.post(name: Self.trialPeriodStateChanged, object: nil)
            }
        }
    }
    
    var state: State {
        if StoreKitManager.InAppPurchaseProduct.goPro.purchaseState == .purchased {
            return .pro
        }
        
        if let data = KeychainManager.get(key: Self.trialBeganDateKey), let trialBeganDate = try? JSONDecoder().decode(Date.self, from: data) {
            if Date().timeIntervalSince(trialBeganDate) > Self.trialPeriodInDays * 24 * 60 * 60 {
                return .trialPeriodExpired
            } else {
                return .trial(trialBeganDate)
            }
        }
        
        return .preTrial
    }
    
    @MainActor
    func canMakeChanges(scene: UIWindowScene) async -> Bool {
        switch self.state {
        case .pro, .trial(_):
            return true
            
        case .trialPeriodExpired:
            return await withCheckedContinuation { (checkedContinuation: CheckedContinuation<Bool, Never>) in
                let alert = UIAlertController(title: NSLocalizedString("trialPeriodExpiredTitle", comment: ""), message: NSLocalizedString("trialPeriodExpiredMessage", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("generalNo", comment: ""), style: .cancel) { _ in
                    checkedContinuation.resume(returning: false)
                })
                alert.addAction(UIAlertAction(title: NSLocalizedString("generalYes", comment: ""), style: .default) { _ in
                    Task {
                        await StoreKitManager.sharedInstance.purchase(product: .goPro)
                        
                        checkedContinuation.resume(returning: StoreKitManager.InAppPurchaseProduct.goPro.purchaseState == .purchased)
                    }
                })
                scene.keyWindow?.rootViewController?.topMostPresentedViewController.present(alert, animated: true)
            }
            
        case .preTrial:
            return await withCheckedContinuation { (checkedContinuation: CheckedContinuation<Bool, Never>) in
                let alert = UIAlertController(title: NSLocalizedString("upgradeToProTitle", comment: ""), message: String(format: NSLocalizedString("upgradeToProMessage", comment: ""), Int(Self.trialPeriodInDays)), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("generalCancel", comment: ""), style: .default) { _ in
                    checkedContinuation.resume(returning: false)
                })
                alert.addAction(UIAlertAction(title: NSLocalizedString("startTrial", comment: ""), style: .cancel) { _ in
                    guard let data = try? JSONEncoder().encode(Date()) else { return }

                    KeychainManager.save(key: Self.trialBeganDateKey, value: data)
                    checkedContinuation.resume(returning: true)
                })
                alert.addAction(UIAlertAction(title: NSLocalizedString("upgradeToPro", comment: ""), style: .default) { _ in
                    Task {
                        await StoreKitManager.sharedInstance.purchase(product: .goPro)
                        
                        checkedContinuation.resume(returning: StoreKitManager.InAppPurchaseProduct.goPro.purchaseState == .purchased)
                    }
                })
                scene.keyWindow?.rootViewController?.topMostPresentedViewController.present(alert, animated: true)
            }
        }
    }
    
    #if DEBUG
    func resetTrialPeriod() {
        KeychainManager.delete(key: Self.trialBeganDateKey)
    }
    #endif
}
