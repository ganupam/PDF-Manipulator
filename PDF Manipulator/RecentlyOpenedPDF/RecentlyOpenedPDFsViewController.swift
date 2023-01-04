//
//  RecentlyOpenedPDFsViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/4/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing
import Combine
import PDFKit

final class RecentlyOpenedPDFsViewController: UIHostingController<RecentlyOpenedPDFsViewController.RecentlyOpenedPDFsView>, TooltipViewDelegate {
    unowned let scene: UIWindowScene
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    
    private var tooltipView: TooltipView?
    private var openFileButtonFrame = CGRect.zero
    @UserDefaultsBackedReadWriteProperty(userDefaultsKey: "RecentlyOpenedPDFsViewController.tutorialTapToOpenPDFShownOnce", defaultValue: false) var tutorialShownOnce
    
    init(scene: UIWindowScene) {
        self.scene = scene
        
        super.init(rootView: RecentlyOpenedPDFsView(scene: scene, parentViewController: nil, openFileButtonFrameBinding: nil))
        
        self.rootView = RecentlyOpenedPDFsView(scene: scene, parentViewController: self, openFileButtonFrameBinding: Binding(get: {
            self.openFileButtonFrame
        }, set: {
            self.openFileButtonFrame = $0
            if let tooltipView = self.tooltipView {
                tooltipView.dismiss(animated: false)
                self.showTutorial()
            }
        }))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Always show the navigation bar not just when scrolled.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.shadowColor = UIColor(white: 180.0/255, alpha: 1)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    func didDismiss(_: TooltipView) {
        self.tooltipView = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard !self.tutorialShownOnce else { return }
        
        self.showTutorial()
        self.tutorialShownOnce = true
    }
    
    private func showTutorial() {
        var config = TooltipView.Configuration()
        config.title = NSAttributedString(string: NSLocalizedString("tutorialTapToOpenPDF", comment: ""))
        config.arrowPointingTo = CGPoint(x: self.openFileButtonFrame.midX + 4, y: self.openFileButtonFrame.maxY)
        config.arrowDirection = .up
        let tooltip = TooltipView(configuration: config)
        tooltip.tooltipViewDelegate = self
        self.tooltipView = tooltip
        tooltip.show(in: self.navigationController!.view, tooltipWidth: nil)
    }
    
    struct RecentlyOpenedPDFsView: View {
        unowned let scene: UIWindowScene
        unowned let parentViewController: UIViewController?
        var openFileButtonFrameBinding: Binding<CGRect>?
        
        private static let horizontalSpacing = 15.0
        private static let minimumColumnWidth = 110.0
        private static let thumbnailHeight = 110.0
        
        @State private var showingFilePicker = false
        @ObservedObject private var recentlyOpenFilesManager = RecentlyOpenFilesManager.sharedInstance
        @State private var thumbnails = [URL : UIImage]()
        @State private var showAnimatedCheckmark = false
        @State private var addToExistingPDFURL: URL? = nil
        @State private var adSize = CGSize.zero
        @State private var adRemovalTransactionState = StoreKitManager.InAppPurchaseProduct.adRemoval.purchaseState
        @State private var selectedURL: URL?
        
        private func pages(from url: URL) -> [PDFPage]? {
            guard url.startAccessingSecurityScopedResource() else { return nil }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            guard let doc = PDFDocument(url: url) else { return nil }
            
            return (0 ..< doc.pageCount).compactMap {
                doc.page(at: $0)
            }
        }
        
        private func contextMenu(url: URL) -> some View {
            let recentlyOpenedURLs = RecentlyOpenFilesManager.sharedInstance.urls.filter { recentlyOpenedURL in
                url != recentlyOpenedURL
            }.prefix(5)

            return Group {
                Section("addPagesToRecentFiles") {
                    ForEach(recentlyOpenedURLs, id: \.self) { destinationURL in
                        if destinationURL != url {
                            Button {
                                guard let pages = self.pages(from: url) else { return }
                                
                                if destinationURL.addPages(pages) {
                                    showAnimatedCheckmark = true
                                }
                            } label: {
                                Label {
                                    Text(destinationURL.lastPathComponent)
                                } icon: {
                                    Image(systemName: "plus.rectangle.portrait")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button {
                        addToExistingPDFURL = url
                    } label: {
                        Label {
                            Text("addPagesToExistingPDF")
                        } icon: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        0.6.dispatchAsyncToMainQueueAfter {
                            withAnimation {
                                RecentlyOpenFilesManager.sharedInstance.removeURL(url)
                            }
                        }
                    } label: {
                        Label("removeFromList", systemImage: "trash")
                    }
                }
            }
        }
        
        private var noRecentlyOpnedFilesView: some View {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Image(systemName: "clock")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                
                Text("noRecentlyOpenedFiles")
                    .bold()
                    .padding(.bottom, 2)
                
                HStack(spacing: 0) {
                    Text("Tap on ")
                    
                    Image(systemName: "folder")

                    Text(" at the top to open a pdf file")
                }
                .font(.subheadline)
                .foregroundColor(.gray)

                Spacer(minLength: 0)
            }
        }
        
        private func imageView(url: URL) -> some View {
            Image(uiImage: thumbnails[url] ?? UIImage())
                .ifTrue(thumbnails[url] == nil) {
                    $0.resizable()
                }
                .overlay {
                    if thumbnails[url] == nil {
                        Text("pdf")
                            .font(.title3)
                            .foregroundColor(.theme)
                            .bold()
                    }
                }
                .overlay {
                    if selectedURL == url {
                        Color.black.opacity(0.2)
                        
                        Menu {
                            contextMenu(url: url)
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.theme, .white)
                                .font(.system(size: 25))
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                .border(url == selectedURL ? Color.theme : .gray, width: url == selectedURL ? 2 : 0.5)
                .frame(width: thumbnails[url] == nil ? Self.thumbnailHeight : nil, height: Self.thumbnailHeight)
        }
        
        private func lazyVGrid(containerSize: CGSize) -> some View {
            LazyVGrid(columns: gridItems(containerWidth: containerSize.width), spacing: 25) {
                ForEach(recentlyOpenFilesManager.urls, id: \.self) { url in
                    VStack(spacing: 0) {
                        imageView(url: url)
                            .onDrag {
                                let itemProvider = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.pdf.identifier)// NSItemProvider(contentsOf: url)!
                                
                                // Support for drag-drop to create new window scene.
                                let activity = NSUserActivity(activityType: .openPDFUserActivityType)
                                activity.userInfo = [String.urlBookmarkDataKey : try! url.bookmarkData()]
                                itemProvider.registerObject(activity, visibility: .all)
                                itemProvider.suggestedName = url.lastPathComponent
                                return itemProvider
                            }
                            .contextMenu {
                                contextMenu(url: url)
                            }
                        
                        Text(verbatim: "\(url.lastPathComponent)")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .truncationMode(.middle)
                            .padding(.top, 8)
                            .font(.subheadline)
                        
                        Text(verbatim: "\(size(of: url))")
                            .lineLimit(1)
                            .padding(.top, 3)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer(minLength: 0)
                    }
                    .onTapGesture {
                        guard let selectedURL else {
                            UIApplication.openPDF(url, requestingScene: self.scene)
                            return
                        }
                        
                        if selectedURL != url {
                            withAnimation(.linear(duration: 0.1)) {
                                self.selectedURL = url
                            }
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom], Self.horizontalSpacing)
        }
        
        var body: some View {
            Group {
                if recentlyOpenFilesManager.urls.isEmpty {
                    noRecentlyOpnedFilesView
                } else {
                    GeometryReader { reader in
                        VStack {
                            ScrollView {
                                HStack {
                                    Label {
                                        Text("recentlyOpenedFiles")
                                    } icon: {
                                        Image(systemName: "clock")
                                    }
                                    .font(.title3.bold())
                                    .padding(.horizontal, 16)
                                    
                                    Spacer()
                                }
                                .padding(.top, 20)

                                lazyVGrid(containerSize: reader.size)
                            }
                            .animation(.linear(duration: 0.2), value: recentlyOpenFilesManager.urls)
                            .onReceive(NotificationCenter.default.publisher(for: RecentlyOpenFilesManager.URLAddedNotification)) { notification in
                                guard let url = notification.userInfo?[RecentlyOpenFilesManager.urlUserInfoKey] as? URL else { return }
                                
                                self.generateThumbnails(urls: [url])
                            }
                            .onReceive(NotificationCenter.default.publisher(for: StoreKitManager.purchaseStateChanged)) { _ in
                                adRemovalTransactionState = StoreKitManager.InAppPurchaseProduct.adRemoval.purchaseState
                            }
                            .onAppear() {
                                generateThumbnails(urls: recentlyOpenFilesManager.urls)
                            }
                            
                            if adRemovalTransactionState != .purchased {
                                GoogleADBannerView(adUnitID: "ca-app-pub-5089136213554560/9674578065", scene: scene, rootViewController: parentViewController!, availableWidth: reader.size.width) { size in
                                    adSize = size
                                }
                                .frame(width: adSize.width, height: adSize.height)
                                .frame(maxWidth: reader.size.width)
                            }
                        }
                    }
                    .overlay {
                        if showAnimatedCheckmark {
                            AnimatedCheckmarkWithText() {
                                showAnimatedCheckmark = false
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            if StoreKitManager.InAppPurchaseProduct.adRemoval.purchaseState != .purchased {
                                Menu {
                                    Button(String(format: NSLocalizedString("adRemovalTitle", comment: ""), StoreKitManager.InAppPurchaseProduct.adRemoval.price) + (adRemovalTransactionState == .deferred ? " (" + NSLocalizedString("deferredTransaction", comment: "") + ")" : "")) {
                                        proceedWithAdRemoval()
                                    }
                                    .disabled(adRemovalTransactionState == .deferred)
                                    
                                    Button(NSLocalizedString("restorePurchases", comment: "")) {
                                        Task {
                                            await StoreKitManager.sharedInstance.restoreAllProductsPurchaseState()
                                        }
                                    }
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                            }
                        }
                    }
                    .sheet(isPresented: .constant(addToExistingPDFURL != nil)) {
                        FilePickerView(operationMode: .open(selectableContentTypes: [UTType.pdf])) { destinationURL in
                            defer {
                                addToExistingPDFURL = nil
                            }
                            
                            guard let destinationURL, let pages = self.pages(from: addToExistingPDFURL!) else { return }

                            if destinationURL.addPages(pages) {
                                showAnimatedCheckmark = true
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: "rootView")
            .navigationTitle("PDF Manipulator")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !recentlyOpenFilesManager.urls.isEmpty {
                        Button(selectedURL == nil ? "selectPages" : "generalDone") {
                            withAnimation(Animation.linear(duration: 0.2)) {
                                if selectedURL == nil {
                                    selectedURL = recentlyOpenFilesManager.urls.first
                                } else {
                                    selectedURL = nil
                                }
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .overlay {
                        GeometryReader { reader in
                            Color.clear
                                .preference(key: FramePreferenceKey.self, value: ["open" : reader.frame(in: .named("rootView"))])
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePickerView(operationMode: .open(selectableContentTypes: [UTType.pdf])) { url in
                    guard let url else { return }
                    
                    UIApplication.openPDF(url, requestingScene: self.scene)
                }
            }
            .onPreferenceChange(FramePreferenceKey.self) { frame in
                openFileButtonFrameBinding?.wrappedValue = frame["open", default: .zero]
            }
        }
        
        private func proceedWithAdRemoval() {
            guard StoreKitManager.canMakePayments else {
                let alert = UIAlertController(title: NSLocalizedString("IAPUnavailableTitle", comment: ""), message: NSLocalizedString("IAPUnavailableSubtitle", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("generalOk", comment: ""), style: .default))
                scene.keyWindow?.rootViewController?.present(alert, animated: true)
                return
            }

            Task {
                await StoreKitManager.sharedInstance.purchase(product: StoreKitManager.InAppPurchaseProduct.adRemoval)
            }
        }
        
        private func size(of url: URL) -> String {
            var unit = "bytes"
            var size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
            if size == 1 {
                unit = "byte"
            } else {
                if size >= 1024 {
                    size /= 1024
                    unit = "KB"
                }
                if size >= 1024 {
                    size /= 1024
                    unit = "MB"
                }
                if size >= 1024 {
                    size /= 1024
                    unit = "GB"
                }
            }
            return "\(size) \(unit)"
        }
        
        private func optimalColumns(containerWidth: CGFloat) -> Int {
            // Let's start with max colums = 15
            for columns in stride(from: 15, to: 1, by: -1) {
                let columnWidth = (containerWidth - (Self.horizontalSpacing * (CGFloat(columns) + 1))) / CGFloat(columns)
                if columnWidth >= Self.minimumColumnWidth {
                    return columns
                }
            }
            
            return 1
        }
        
        private func gridItems(containerWidth: CGFloat) -> [GridItem] {
            let columns = optimalColumns(containerWidth: containerWidth)
            return (0 ..< columns).map { _ in
                GridItem(.flexible(minimum: Self.minimumColumnWidth), spacing: Self.horizontalSpacing)
            }
        }
        
        private func generateThumbnails(urls: [URL], size: CGSize = CGSize(width: .greatestFiniteMagnitude, height: Self.thumbnailHeight)) {
            urls.forEach { url in
                guard url.startAccessingSecurityScopedResource() else { return }
                
                let request = QLThumbnailGenerator.Request(fileAt: url,
                                                           size: size,
                                                           scale: UIScreen.main.scale,
                                                           representationTypes: .thumbnail)
                
                QLThumbnailGenerator.shared.generateRepresentations(for: request) { (thumbnail, _, error) in
                    url.stopAccessingSecurityScopedResource()
                    
                    DispatchQueue.main.async {
                        guard let thumbnail, error == nil else { return }
                        
                        let image = thumbnail.uiImage
                        if image.size.width > 110 {
                            generateThumbnails(urls: [url], size: CGSize(width: 110.0, height: .greatestFiniteMagnitude))
                        } else {
                            thumbnails[url] = image
                        }
                    }
                }
            }
        }
    }
}
