//
//  GoogleADBannerView.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/25/22.
//

import SwiftUI
import GoogleMobileAds

struct GoogleADBannerView: UIViewRepresentable {
    let adUnitID: String
    let scene: UIWindowScene
    let rootViewController: UIViewController
    let availableWidth: CGFloat
    let adReceived: ((CGSize) -> Void)?
    
    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(availableWidth))
        bannerView.backgroundColor = .clear
        
        #if DEBUG
        let unitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        let unitID = adUnitID
        #endif
        
        bannerView.adUnitID = unitID
        bannerView.rootViewController = rootViewController
        bannerView.delegate = context.coordinator
        let request = GADRequest()
        request.scene = self.scene
        bannerView.load(request)
        return bannerView
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {
        uiView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(availableWidth)
        let request = GADRequest()
        request.scene = self.scene
        uiView.load(request)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(adReceived: adReceived)
    }

    final class Coordinator: NSObject, GADBannerViewDelegate {
        let adReceived: ((CGSize) -> Void)?
        
        init(adReceived: ((CGSize) -> Void)?) {
            self.adReceived = adReceived
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            adReceived?(bannerView.adSize.size)
        }
    }
}
