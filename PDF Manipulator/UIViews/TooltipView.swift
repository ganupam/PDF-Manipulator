//
//  TooltipView.swift
//  midomi
//
//  Created by Anupam Godbole on 2/20/19.
//  Copyright © 2019 SoundHound. All rights reserved.
//

/* Usage:
 
 var config = TooltipView.Configuration()
 config.title = "Search lyrics!"
 config.subtitle = "Type in the words, tap the mic, or say “OK Hound…”"
 config.arrowPointingTo = CGPoint(x: 300, y: 50)
 config.tooltipCenterOffsetXFromArrowCenterX = -100
 let tooltipView = TooltipView(configuration: config)
 tooltipView.show(width: 244, in: self.contentView)
 
 */

import UIKit
import QuartzCore

@objc protocol TooltipViewDelegate {
    func didDismiss(_: TooltipView)
}

final class TooltipView: SHUTouchesInterceptorView {
    enum ArrowDirection: Int {
        case up
        case down
    }

    struct Configuration {
        static let defaultPadding: CGFloat = 10
        
        var title, subtitle: NSAttributedString?
        var titleColor: UIColor = UIColor.white
        var subtitleColor: UIColor = UIColor.black
        var titleFont: UIFont = UIFont.systemFont(ofSize: 16)
        var subtitleFont: UIFont = UIFont.systemFont(ofSize: 14)
        var arrowPointingTo: CGPoint = CGPoint.zero
        var arrowDirection: ArrowDirection = .up
        var arrowHeight: CGFloat = 20.0
        var tooltipCenterOffsetXFromArrowCenterX: CGFloat = 0
        var backgroundColor: UIColor = .init(red: 7.0/255, green: 125.0/255, blue: 1, alpha: 1)
        var padding: CGFloat = Configuration.defaultPadding
        var multilineTextAlignment = NSTextAlignment.left
        var containerViewBackgroundColor = UIColor.clear
    }
    
    private(set) var configuration: Configuration
    
    var shouldDismissOnTappingOutside = true
    
    weak var tooltipViewDelegate: TooltipViewDelegate?
    
    private let containerView: UIView = {
        let v = UIView(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 4
        return v
    }()
    
    private lazy var arrowView: UIImageView = {
        let image = UIImage(named: "tooltipPointer")!
        let arrowView = UIImageView(image: image)
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.tintColor = self.configuration.backgroundColor
        return arrowView
    }()

    private lazy var downArrowView: UIImageView = {
        let image = UIImage(named: "tooltipPointerDownArrow")!
        let downArrowView = UIImageView(image: image)
        downArrowView.translatesAutoresizingMaskIntoConstraints = false
        downArrowView.tintColor = self.configuration.backgroundColor
        return downArrowView
    }()
    
    private(set) lazy var title: UILabel = {
        let title = UILabel(frame: .zero)
        title.font = self.configuration.titleFont
        title.textColor = self.configuration.titleColor
        title.attributedText = self.configuration.title
        title.translatesAutoresizingMaskIntoConstraints = false
        title.setContentHuggingPriority(UILayoutPriority(rawValue: 999), for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        title.textAlignment = self.configuration.multilineTextAlignment
        title.numberOfLines = 0
        return title
    }()

    private(set) lazy var subtitle: UILabel = {
        let subtitle = UILabel(frame: .zero)
        subtitle.font = self.configuration.subtitleFont
        subtitle.textColor = self.configuration.subtitleColor
        subtitle.attributedText = self.configuration.subtitle
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.setContentHuggingPriority(UILayoutPriority(rawValue: 999), for: .horizontal)
        subtitle.setContentCompressionResistancePriority(.required, for: .horizontal)
        subtitle.textAlignment = self.configuration.multilineTextAlignment
        subtitle.numberOfLines = 0
        return subtitle
    }()
    
    private lazy var arrowLayer = {
        let arrowLayer = CALayer()
        arrowLayer.backgroundColor = self.configuration.backgroundColor.cgColor
        return arrowLayer
    }()

    init(configuration: Configuration) {
        self.configuration = configuration

        super.init(frame: .zero)
        
        if let title = self.configuration.title {
            let title = NSMutableAttributedString(attributedString: title)
            title.addAttributes([NSAttributedString.Key.font : self.configuration.titleFont], range: NSRange(location: 0, length: title.length))
            self.configuration.title = title
        }
        
        self.delegate = self
    }
    
    private func width(viewForBounds: UIView) -> CGFloat {
        var attributedText: NSAttributedString
        switch (self.configuration.title, self.configuration.subtitle) {
        case (let title?, let subtitle?):
            let titleWidth = title.calculateSizeForSingleLineDrawing(with: 10000).width
            let subtitleWidth = subtitle.calculateSizeForSingleLineDrawing(with: 10000).width
            attributedText = (titleWidth >= subtitleWidth ? title : subtitle)
            
        case (let title?, nil):
            attributedText = title
        
        case (nil, let subtitle?):
            attributedText = subtitle

        case (nil, nil):
            precondition(false, "Both title and subtitle can't be nil.")
            attributedText = NSAttributedString()
        }
        
        return attributedText.calculateSizeForMultilineDrawing(with: viewForBounds.bounds.width - (self.configuration.padding * 2 + TooltipView.Configuration.defaultPadding * 2)).width + self.configuration.padding * 2
    }
    
    private func effectiveTooltipCenterOffsetXFromArrowCenterX(parentView: UIView, viewForBounds: UIView, width: CGFloat) -> CGFloat {
        if self.configuration.tooltipCenterOffsetXFromArrowCenterX != 0 {
            return self.configuration.tooltipCenterOffsetXFromArrowCenterX
        }
        
        let arrowPointingToXInViewForBounds = viewForBounds.convert(self.configuration.arrowPointingTo, from: parentView).x
        if (arrowPointingToXInViewForBounds - width / 2) < TooltipView.Configuration.defaultPadding {
            return ((width / 2) - 20)
        } else if (width / 2 + arrowPointingToXInViewForBounds) > (viewForBounds.bounds.width - TooltipView.Configuration.defaultPadding) {
            return -((width / 2) - 20)
        }
        return 0
    }
    
    ///
    /// - Parameters:
    ///   - parentView: Tooltip view is added as a child to the parent view
    ///   - tooltipWidth: The width of the tooltip view. It's calculated on the fly if nil.
    ///   - viewForBounds: The view to be used to calculate tooltipCenterOffsetXFromArrowCenterX. If it's nil, parent view is used.
    func show(in parentView: UIView, tooltipWidth: CGFloat? = nil, viewForBounds: UIView? = nil, animated: Bool = true) {
        let viewForBounds = viewForBounds ?? parentView
        self.frame = viewForBounds.bounds
        
        self.backgroundColor = self.configuration.containerViewBackgroundColor
        parentView.addSubview(self)
        
        self.layer.addSublayer(self.arrowLayer)
        
        self.addSubview(self.containerView)
        self.containerView.backgroundColor = self.configuration.backgroundColor
        
        self.prepareContainerView()
        configuration.arrowDirection == .up ? self.addArrowView() : self.addDownArrowView()
        
        var maxWidth: CGFloat
        if let tooltipWidth_ = tooltipWidth {
            maxWidth = tooltipWidth_
        } else {
            maxWidth = self.width(viewForBounds: viewForBounds)
        }
        
        let size = self.containerView.systemLayoutSizeFitting(CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        
        let tooltipCenterOffset = self.effectiveTooltipCenterOffsetXFromArrowCenterX(parentView: parentView, viewForBounds: viewForBounds, width: maxWidth)
        if self.configuration.arrowDirection == .down {
            NSLayoutConstraint.activate([
                self.containerView.widthAnchor.constraint(equalToConstant: size.width)
                , self.containerView.heightAnchor.constraint(equalToConstant: size.height)
                , self.containerView.centerXAnchor.constraint(equalTo: self.downArrowView.centerXAnchor, constant: tooltipCenterOffset)
                , self.containerView.bottomAnchor.constraint(equalTo: self.downArrowView.topAnchor)
                ])
        } else {
            NSLayoutConstraint.activate([
                self.containerView.widthAnchor.constraint(equalToConstant: size.width)
                , self.containerView.heightAnchor.constraint(equalToConstant: size.height)
                , self.containerView.centerXAnchor.constraint(equalTo: self.arrowView.centerXAnchor, constant: tooltipCenterOffset)
                , self.containerView.topAnchor.constraint(equalTo: self.arrowView.bottomAnchor, constant: self.configuration.arrowHeight)
                ])
        }
        
        guard animated else {
            return
        }
        
        self.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let arrowWidth = 3.0
        let arrowFrame = CGRect(x: self.arrowView.frame.midX - arrowWidth / 2, y: self.arrowView.frame.maxY, width: arrowWidth, height: self.containerView.frame.minY - self.arrowView.frame.maxY)
        self.arrowLayer.frame = arrowFrame
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func prepareContainerView() {
        if self.configuration.title != nil {
            self.containerView.addSubview(self.title)
            self.containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(padding)-[title]-(padding)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: ["padding" : self.configuration.padding], views: ["title" : self.title]))
        }
        
        if self.configuration.subtitle != nil {
            self.containerView.addSubview(self.subtitle)
            self.containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(padding)-[subtitle]-(padding)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: ["padding" : self.configuration.padding], views: ["subtitle" : self.subtitle]))
        }

        switch (self.configuration.title, self.configuration.subtitle) {
        case (_?, _?):
            self.containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(padding)-[title][subtitle]-(padding)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: ["padding" : self.configuration.padding], views: ["title" : self.title, "subtitle" : self.subtitle]))

        case (_?, nil):
            self.containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(padding)-[title]-(padding)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: ["padding" : self.configuration.padding], views: ["title" : self.title]))

        case (nil, _?):
            self.containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(padding)-[subtitle]-(padding)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: ["padding" : self.configuration.padding], views: ["subtitle" : self.subtitle]))

        default:
            assert(false, "Both title, subtitle cannot be nil")
            break
        }
    }
    
    private func addArrowView() {
        self.addSubview(self.arrowView)
        
        NSLayoutConstraint.activate([
            self.arrowView.widthAnchor.constraint(equalToConstant: self.arrowView.image?.size.width ?? 0)
            , self.arrowView.heightAnchor.constraint(equalToConstant: self.arrowView.image?.size.height ?? 0)
            , self.arrowView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: self.configuration.arrowPointingTo.x - (self.arrowView.image?.size.width ?? 0) / 2)
            , self.arrowView.topAnchor.constraint(equalTo: self.topAnchor, constant: self.configuration.arrowPointingTo.y)
            ])
    }

    private func addDownArrowView() {
        self.addSubview(self.downArrowView)

        NSLayoutConstraint.activate([
            self.downArrowView.widthAnchor.constraint(equalToConstant: self.downArrowView.image?.size.width ?? 0)
            , self.downArrowView.heightAnchor.constraint(equalToConstant: self.downArrowView.image?.size.height ?? 0)
            , self.downArrowView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: self.configuration.arrowPointingTo.x - (self.downArrowView.image?.size.width ?? 0) / 2)
            , self.downArrowView.topAnchor.constraint(equalTo: self.topAnchor, constant: self.configuration.arrowPointingTo.y)
            ])
    }

    func dismiss(animated: Bool = true, completionHandler: (()->Void)? = nil) {
        func completed() {
            self.removeFromSuperview()
            self.tooltipViewDelegate?.didDismiss(self)
            completionHandler?()
        }
        
        guard animated else {
            completed()
            return
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { (completion) in
            completed()
        }
    }
}

extension TooltipView: SHUTouchesInterceptorViewDelegate {
    func allowTouchToPassThrough(_ point: CGPoint, view: SHUTouchesInterceptorView, event: UIEvent?) -> Bool {
        if self.shouldDismissOnTappingOutside {
            self.dismiss()
        }
        
        let pointInContainer = self.containerView.convert(point, from: view)
        return !self.containerView.point(inside: pointInContainer, with: event)
    }
}
