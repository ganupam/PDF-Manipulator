//
//  SHUTouchesInterceptorView.swift
//  midomi
//
//  Created by Anupam Godbole on 3/28/16.
//  Copyright © 2016 SoundHound. All rights reserved.
//

import Foundation
import UIKit

@objc protocol SHUTouchesInterceptorViewDelegate {
    func allowTouchToPassThrough(_ point: CGPoint, view: SHUTouchesInterceptorView, event: UIEvent?) -> Bool
}

class SHUTouchesInterceptorView: UIView {
    weak var delegate: SHUTouchesInterceptorViewDelegate?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let allowToPassThrough = delegate?.allowTouchToPassThrough(point, view: self, event: event) ?? false
        return allowToPassThrough ? nil : super.hitTest(point, with: event)
    }
}
