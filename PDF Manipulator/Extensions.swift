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

extension UIAlertController {
    static func show(title: String? = nil, message: String? = nil, defaultButtonTitle: String = NSLocalizedString("generalOK", comment: ""), scene: UIWindowScene) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: defaultButtonTitle, style: .default))
        scene.keyWindow?.rootViewController?.present(alert, animated: true)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [String : CGRect] = [:]
    
    static func reduce(value: inout [String : CGRect], nextValue: () -> [String : CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/*
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
}*/

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
        var bookmarkDataIsStale = false

        guard let bookmarkData = self.userInfo?[.urlBookmarkDataKey] as? Data, let url = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &bookmarkDataIsStale) else { return nil }
        
        if bookmarkDataIsStale, let newBookmarkData = try? url.bookmarkData() {
            self.userInfo?[.urlBookmarkDataKey] = newBookmarkData
        }
        
        return url
    }
    
    private static var pdfManagerKey = "pdfManagerKey"
    var pdfManager: PDFManager? {
        get {
            guard self.configuration.name == .openedPDFConfigurationName else { return nil }
            
            return objc_getAssociatedObject(self, &Self.pdfManagerKey) as? PDFManager
        }
        
        set {
            guard self.configuration.name == .openedPDFConfigurationName else { return }
            
            objc_setAssociatedObject(self, &Self.pdfManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension Double {
    @inline(__always) func dispatchAsyncToMainQueueAfter(_ execute: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + self, execute: execute)
    }
}

extension UIApplication {
    class func openPDF(_ url: URL, requestingScene: UIWindowScene) {
        guard url.startAccessingSecurityScopedResource() else {
            UIAlertController.show(message: NSLocalizedString("unableToOpen", comment: ""), scene: requestingScene)
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let bookmarkData = try? url.bookmarkData() else {
            UIAlertController.show(message: NSLocalizedString("unableToOpen", comment: ""), scene: requestingScene)
            return
        }
        
        if UIApplication.shared.supportsMultipleScenes {
            let session = UIApplication.shared.openSessions.first {
                guard let data = $0.userInfo?[.urlBookmarkDataKey] as? Data else { return false }
                
                var stale = false
                return (try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)) == url
            }
            
            let activationOptions = UIWindowScene.ActivationRequestOptions()
            activationOptions.requestingScene = requestingScene
            
            let userActivity: NSUserActivity?
            if session == nil {
                userActivity = NSUserActivity(activityType: .openPDFUserActivityType)
                userActivity?.userInfo = [String.urlBookmarkDataKey : bookmarkData]
            } else {
                userActivity = nil
            }
            UIApplication.shared.requestSceneSessionActivation(session, userActivity: userActivity, options: activationOptions)
            RecentlyOpenFilesManager.sharedInstance.addURL(url)
        } else {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let pdfManager = PDFManager(url: url, scene: scene) else {
                UIAlertController.show(message: NSLocalizedString("unableToOpen", comment: ""), scene: requestingScene)
                return
            }

            let navVC = (scene.keyWindow?.rootViewController as? UINavigationController)
            
            func openPDF() {
                let vc = PDFPagesViewController(pdfManager: pdfManager, scene: scene)
                navVC?.pushViewController(vc, animated: true)
                RecentlyOpenFilesManager.sharedInstance.addURL(url)
            }
            
            guard navVC?.topViewController is RecentlyOpenedPDFsViewController else {
                let alert = UIAlertController(title: NSLocalizedString("iPhoneOpenPDFConfirmationTitle", comment: ""), message: String(format: NSLocalizedString("iPhoneOpenPDFConfirmationMessage", comment: ""), url.lastPathComponent), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("generalCancel", comment: ""), style: .cancel))
                alert.addAction(UIAlertAction(title: NSLocalizedString("generalOK", comment: ""), style: .default) { _ in
                    navVC?.popToRootViewController(animated: false)
                    openPDF()
                })
                navVC?.present(alert, animated: true)
                return
            }
            
            openPDF()
        }
    }
    
    class func activateRecentlyOpenedPDFsScene(requestingScene: UIWindowScene) {
        let session = UIApplication.shared.openSessions.first {
            $0.configuration.name == "Default Configuration"
        }

        let activationOptions = UIWindowScene.ActivationRequestOptions()
        activationOptions.requestingScene = requestingScene
        UIApplication.shared.requestSceneSessionActivation(session, userActivity: nil, options: activationOptions)
    }
}

extension URL {
    static var documentsFolder: URL {
        if #available(iOS 16.0, *) {
            return URL.documentsDirectory
        } else {
            let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            return URL(fileURLWithPath: docPath)
        }
    }
    
    func addPages(_ pages: [PDFPage]) -> Bool {
        guard self.startAccessingSecurityScopedResource() else { return false }
        
        defer {
            self.stopAccessingSecurityScopedResource()
        }
        
        guard let doc = PDFDocument(url: self) else { return false }
        
        for page in pages {
            doc.insert(page, at: doc.pageCount)
        }
        
        return doc.write(to: self)
    }
}

extension View {
    @ViewBuilder
    func contextMenus<M, P>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View where M : View, P : View {
        if #available(iOS 16, *) {
            self.contextMenu(menuItems: menuItems, preview: preview)
        } else {
            self.contextMenu(menuItems: menuItems)
        }
    }
    
    @ViewBuilder
    func ifTrue<T: View>(_ condition: @autoclosure () -> Bool, apply:(Self) -> T) -> some View {
        if condition() {
            apply(self) // 'Self' is not convertible to 'T'
        } else {
            self
        }
    }
}

extension NSAttributedString {
    private func attributedString(byRemovingAttributes attributes: [NSAttributedString.Key]) -> NSAttributedString {
        let attribString = NSMutableAttributedString()
        self.enumerateAttributes(in: NSRange(location: 0, length: self.length)) { attrs, range, stop in
            var dict = attrs
            attributes.forEach {
                dict.removeValue(forKey: $0)
            }
            attribString.append(NSAttributedString(string: self.string, attributes: dict))
        }
        
        return attribString
    }

    func calculateSizeForMultilineDrawing(with maxWidth: CGFloat) -> CGSize {
        let str = self.attributedString(byRemovingAttributes: [NSAttributedString.Key.paragraphStyle])
        let rectBound = str.boundingRect(with: CGSize(width: maxWidth, height: 1000), options: .usesLineFragmentOrigin, context: nil)
        return CGSize(width: ceil(rectBound.size.width), height: ceil(rectBound.size.height))
    }
    
    func calculateSizeForSingleLineDrawing(with maxWidth: CGFloat) -> CGSize {
        let str = self.attributedString(byRemovingAttributes: [NSAttributedString.Key.paragraphStyle])
        let rectBound = str.boundingRect(with: CGSize(width: maxWidth, height: 1000), context: nil)
        return CGSize(width: ceil(rectBound.size.width), height: ceil(rectBound.size.height))
    }
}

@propertyWrapper
struct UserDefaultsBackedReadWriteProperty<Type> {
    private(set) var userDefaultsKey: String
    private(set) var defaultValue: Type
    
    var wrappedValue: Type {
        get {
            (UserDefaults.standard.object(forKey: self.userDefaultsKey) as? Type) ?? self.defaultValue
        }
        
        nonmutating set {
            if case Optional<Any>.none = newValue as Any {
                UserDefaults.standard.removeObject(forKey: self.userDefaultsKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: self.userDefaultsKey)
            }
            UserDefaults.standard.synchronize()
        }
    }
}
