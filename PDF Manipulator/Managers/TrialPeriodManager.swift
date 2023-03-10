//
//  TrialPeriodManager.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 3/10/23.
//

import Foundation
import Combine

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
        
        if let trialBeganDate = KeychainManager.get(key: Self.trialBeganDateKey) as? Date {
            if Date().timeIntervalSince(trialBeganDate) > Self.trialPeriodInDays * 24 * 60 * 60 {
                return .trialPeriodExpired
            } else {
                return .trial(trialBeganDate)
            }
        }
        
        return .preTrial
    }
}
