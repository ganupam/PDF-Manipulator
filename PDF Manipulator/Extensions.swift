//
//  SwiftUI+Extensions.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 9/13/22.
//

import Foundation
import SwiftUI
import UIKit
import PDFKit

extension String {
    static var openPDFUserActivityType: String {
        (Bundle.main.bundleIdentifier ?? "") + ".openpdf"
    }
    
    static var openedPDFConfigurationName: String {
       "Opened PDF Configuration"
    }
    
    static var urlBookmarkDataKey: String {
        "urlBookmarkData"
    }
}

private struct URLEnvironmentKey: EnvironmentKey {
    static let defaultValue: URL = URL(string: "www.apple.com")!
}

private struct WindowSceneEnvironmentKey: EnvironmentKey {
    static let defaultValue: UIWindowScene? = nil
}

extension EnvironmentValues {
    var pdfUrl: URL {
        get { self[URLEnvironmentKey.self] }
        set { self[URLEnvironmentKey.self] = newValue }
    }
    
    var windowScene: UIWindowScene? {
        get { self[WindowSceneEnvironmentKey.self] }
        set { self[WindowSceneEnvironmentKey.self] = newValue }
    }
}

extension UIAlertController {
    static func show(title: String? = nil, message: String? = nil, defaultButtonTitle: String = NSLocalizedString("generalOK", comment: ""), scene: UIWindowScene) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: defaultButtonTitle, style: .default))
        scene.keyWindow?.rootViewController?.present(alert, animated: true)
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

struct ScrollViewWithDidScroll<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let offsetChanged: (CGPoint) -> Void
    let content: Content

    init(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        offsetChanged: @escaping (CGPoint) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.offsetChanged = offsetChanged
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).origin
                )
            }.frame(width: 0, height: 0)
            content
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: offsetChanged)
    }
}

extension FloatingPoint {
    @inline(__always) static func interpolate(initialX: Self, initialY: Self, finalX: Self, finalY: Self, currentX: Self) -> Self {
        if finalX < initialX {
            if currentX < finalX && currentX < initialX {
                return finalY
            } else if currentX > finalX && currentX > initialX {
                return initialY
            } else {
                let tmp = (finalY - initialY) * (currentX - initialX) / (finalX - initialX)
                return initialY + tmp
            }
        } else {
            if currentX < finalX && currentX < initialX {
                return initialY
            } else if currentX > finalX && currentX > initialX {
                return finalY
            } else {
                let tmp = (finalY - initialY) * (currentX - initialX) / (finalX - initialX)
                return initialY + tmp
            }
        }
    }
}

extension UISceneSession {
    var url: URL? {
        var bookmarkDataIsStale = true
        guard let bookmarkData = self.userInfo?[.urlBookmarkDataKey] as? Data else { return nil }
        return try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale)
    }
    
    private static var pdfDocKey = "pdfDocKey"
    var pdfDoc: PDFDocument? {
        get {
            guard self.configuration.name == .openedPDFConfigurationName else { return nil }
            
            return objc_getAssociatedObject(self, &Self.pdfDocKey) as? PDFDocument
        }
        
        set {
            guard self.configuration.name == .openedPDFConfigurationName else { return }
            
            objc_setAssociatedObject(self, &Self.pdfDocKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func addPages(_ pages: [PDFPage]) {
        guard self.configuration.name == .openedPDFConfigurationName, let doc = self.pdfDoc else { return }
        
        let pagesModel = PDFPagesModel(pdf: doc, displayScale: 1)
        pagesModel.insertPages(pages, at: doc.pageCount)
    }
}

extension Double {
    @inline(__always) func dispatchAsyncToMainQueueAfter(_ execute: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + self, execute: execute)
    }
}
