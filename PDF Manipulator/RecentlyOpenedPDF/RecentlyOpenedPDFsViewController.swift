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

final class RecentlyOpenedPDFsViewController: UIHostingController<RecentlyOpenedPDFsViewController.RecentlyOpenedPDFsView> {
    let scene: UIWindowScene
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    
    init(scene: UIWindowScene) {
        self.scene = scene
        
        super.init(rootView: RecentlyOpenedPDFsView())        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rootView = RecentlyOpenedPDFsView(scene: self.scene)
        
        // Always show the navigation bar not just when scrolled.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.shadowColor = UIColor(white: 180.0/255, alpha: 1)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    struct RecentlyOpenedPDFsView: View {
        private static let horizontalSpacing = 15.0
        private static let minimumColumnWidth = 110.0
        private(set) var scene: UIWindowScene? = nil
        private static let thumbnailHeight = 110.0
        
        @State private var showingFilePicker = false
        @ObservedObject private var recentlyOpenFilesManager = RecentlyOpenFilesManager.sharedInstance
        @State private var thumbnails = [URL : UIImage]()
        
        var body: some View {
            GeometryReader { reader in
                ScrollView {
                    HStack {
                        Text("recentlyOpenedFiles")
                            .font(.title2.bold())
                            .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    LazyVGrid(columns: gridItems(containerWidth: reader.size.width), spacing: 25) {
                        ForEach(recentlyOpenFilesManager.urls, id: \.self) { url in
                            VStack(spacing: 0) {
                                Image(uiImage: thumbnails[url] ?? UIImage())
                                    .border(.gray, width: 0.5)
                                    .frame(height: Self.thumbnailHeight)
                                
                                Text(verbatim: "\(url.lastPathComponent)")
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
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
                                UIApplication.openPDF(url, requestingScene: self.scene!)
                            }
                        }
                    }
                    .padding(Self.horizontalSpacing)
                }
                .animation(.linear(duration: 0.2), value: recentlyOpenFilesManager.urls)
                .navigationTitle("PDF Manipulator")
                .onReceive(NotificationCenter.default.publisher(for: RecentlyOpenFilesManager.URLAddedNotification)) { notification in
                    guard let url = notification.userInfo?[RecentlyOpenFilesManager.urlUserInfoKey] as? URL else { return }
                    
                    self.generateThumbnails(urls: [url])
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePickerView(operationMode: .open(selectableContentTypes: [UTType.pdf])) { url in
                    guard let url else { return }
                    
                    UIApplication.openPDF(url, requestingScene: self.scene!)
                }
            }
            .onAppear() {
                generateThumbnails(urls: recentlyOpenFilesManager.urls)
            }
        }
        
        private func size(of url: URL) -> String {
            var unit = "byte"
            var size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
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
            
            preconditionFailure("Control flow shouldn't be here!")
        }
        
        private func gridItems(containerWidth: CGFloat) -> [GridItem] {
            let columns = optimalColumns(containerWidth: containerWidth)
            return (0 ..< columns).map { _ in
                GridItem(.flexible(minimum: Self.minimumColumnWidth), spacing: Self.horizontalSpacing)
            }
        }
        
        private func generateThumbnails(urls: [URL], size: CGSize = CGSize(width: .greatestFiniteMagnitude, height: Self.thumbnailHeight)) {
            urls.forEach { url in
                let request = QLThumbnailGenerator.Request(fileAt: url,
                                                           size: size,
                                                           scale: UIScreen.main.scale,
                                                           representationTypes: .thumbnail)
                
                QLThumbnailGenerator.shared.generateRepresentations(for: request) { (thumbnail, _, error) in
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
