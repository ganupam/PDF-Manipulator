//
//  PDFThumbnailsViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

final class PDFThumbnailsViewController: UIHostingController<PDFThumbnailsViewController.OuterPDFThumbnailView> {
    private static let supportedDroppedItemProviders = [UTType.pdf, UTType.jpeg, UTType.gif, UTType.bmp, UTType.png, UTType.tiff]
    
    let pdfDoc: PDFDocument
    let scene: UIWindowScene
    
    init(pdfDoc: PDFDocument, scene: UIWindowScene) {
        self.pdfDoc = pdfDoc
        self.scene = scene
        
        super.init(rootView: OuterPDFThumbnailView(pdfDoc: pdfDoc, scene: scene))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PDFThumbnailsViewController {
    struct OuterPDFThumbnailView: View {
        let pdfDoc: PDFDocument
        let scene: UIWindowScene
        
        var body: some View {
            PDFThumbnails(pdfDoc: pdfDoc, scene: scene)
                .environment(\.windowScene, scene)
        }
    }
    
    struct PDFThumbnails: View {
        let pdfDoc: PDFDocument
        let scene: UIWindowScene
        @State private var isSelected: [Bool]
        @StateObject private var pagesModel: PDFPagesModel
        @State private var pageIDs: [UUID]
        @State private var draggingPageID: UUID?
        @State private var dragStarted = false
        @State private var externalDropFakePageIndex: Int? = nil
        @State private var activePageIndex = 0
        @State private var inSelectionMode = false

        private static let horizontalSpacing = 10.0
        private static let verticalSpacing = 15.0
        private static let gridPadding = 15.0
        
        init(pdfDoc: PDFDocument, scene: UIWindowScene) {
            self.pdfDoc = pdfDoc
            self.scene = scene
            _isSelected = State(initialValue: Array(repeating: false, count: pdfDoc.pageCount))
            let pdfPagesModel = PDFPagesModel(pdf: pdfDoc, displayScale: Double(scene.keyWindow?.screen.scale ?? 2.0))
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
            
            var IDs = [UUID]()
            for _ in 0 ..< pdfDoc.pageCount {
                IDs.append(UUID())
            }
            _pageIDs = State(initialValue: IDs)
        }
        
        private func dragItemProvider(pageIndex: Int) -> NSItemProvider {
            let itemProvider = NSItemProvider()
            itemProvider.suggestedName = self.pdfDoc.documentURL?.lastPathComponent
            itemProvider.registerItem(forTypeIdentifier: UTType.pdf.identifier) { completionHandler, classType, dict in
                guard completionHandler != nil, let pdfName = self.pdfDoc.documentURL?.lastPathComponent, let page = self.pdfDoc.page(at: pageIndex)?.dataRepresentation else {
                    completionHandler?(nil, NSError(domain: "", code: 1))
                    return
                }
                
                let pdfPath = FileManager.default.temporaryDirectory.appendingPathComponent(pdfName)
                
                do {
                    try page.write(to: pdfPath)
                }
                catch {
                    completionHandler?(nil, NSError(domain: "", code: 1))
                    return
                }
                
                completionHandler?(pdfPath as NSSecureCoding, nil)
            }
            return itemProvider
        }
        
        var body: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ScrollViewReader { scrollReader in
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                                ForEach(0 ..< pagesModel.images.count + ((externalDropFakePageIndex != nil) ? 1 : 0), id: \.self) { pageIndex in
                                    if pageIndex == externalDropFakePageIndex {
                                        VStack(spacing: 0) {
                                            Color.gray.opacity(0.5)
                                                .border(.black, width: 0.5)
                                                .frame(height: 1.29 * (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2)
                                            
                                            Spacer()
                                        }
                                    } else {
                                        createThumbnail(width: (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2, pageIndex: pageIndex)
                                    }
                                }
                            }
                            .ignoresSafeArea(.all, edges: .top)
                            .padding(Self.gridPadding)
                        }
                        .onDrop(of: PDFThumbnailsViewController.supportedDroppedItemProviders, delegate: ScrollViewDropDelegate(pageIndex:pagesModel.images.count, externalDropFakePageIndex: $externalDropFakePageIndex, dropped: self.handleDropItemProviders))
                        .onReceive(NotificationCenter.default.publisher(for: Common.activePageChangedNotification)) { notification in
                            guard (notification.object as? PDFPagesModel)?.pdf.documentURL == pdfDoc.documentURL, let pageIndex = notification.userInfo?[Common.activePageIndexKey] as? Int else { return }

                            withAnimation(.linear(duration: 0.1)) {
                                //scrollReader.scrollTo(pageIDs[pageIndex])
                                activePageIndex = pageIndex
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: PDFPagesModel.willInsertPages)) { notification in
                guard (notification.object as? PDFPagesModel)?.pdf.documentURL == pdfDoc.documentURL else { return }
                
                guard let indices = notification.userInfo?[PDFPagesModel.pagesIndicesKey] as? [Int] else { return }
                
                for index in indices {
                    isSelected.insert(false, at: index)
                    pageIDs.insert(UUID(), at: index)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: PDFPagesModel.willDeletePages)) { notification in
                guard (notification.object as? PDFPagesModel)?.pdf.documentURL == pdfDoc.documentURL else { return }

                guard let indices = notification.userInfo?[PDFPagesModel.pagesIndicesKey] as? [Int] else { return }
                
                for index in indices {
                    isSelected.remove(at: index)
                    pageIDs.remove(at: index)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {

                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
        }
        
        private func handleDropItemProviders(_ itemProviders: [NSItemProvider]) {
            var pages = [PDFPage]()
            var urls = [URL]()
            let group = DispatchGroup()
            
            itemProviders.forEach { itemProvider in
                guard let typeIdentifier = (PDFThumbnailsViewController.supportedDroppedItemProviders.first {
                    itemProvider.registeredTypeIdentifiers.contains($0.identifier)
                }) else { return }
                
                group.enter()
                itemProvider.loadItem(forTypeIdentifier: typeIdentifier.identifier) { (data, error) in
                    defer {
                        group.leave()
                    }
                    
                    guard let url = data as? URL, url.startAccessingSecurityScopedResource() else { return }
                    
                    DispatchQueue.main.sync {
                        urls.append(url)
                        
                        pages.append(contentsOf: self.pdfPages(from: url, typeIdentifier: typeIdentifier))
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.pagesModel.insertPages(pages, at: externalDropFakePageIndex ?? 0)
                self.externalDropFakePageIndex = nil
                
                urls.forEach {
                    $0.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        private func pdfPages(from url: URL, typeIdentifier: UTType) -> [PDFPage] {
            switch typeIdentifier {
            case .pdf:
                guard let pdf = PDFDocument(url: url) else { return [] }
                
                var pages = [PDFPage]()
                for i in 0 ..< pdf.pageCount {
                    guard let page = pdf.page(at: i) else { continue }
                    
                    pages.append(page)
                }
                
                return pages
                
            case .jpeg, .png, .tiff, .gif, .bmp:
                // UIImage supports above formats.
                guard let data = try? Data(contentsOf: url), let image = UIImage(data: data), let page = PDFPage(image: image) else { return [] }
                
                return [page]
                
            default:
                return []
            }
        }
        
        private func menu(adjustedPageIndex: Int) -> some View {
            Group {
                Section {
                    Button {
                        pagesModel.rotateLeft(adjustedPageIndex)
                    } label: {
                        Label {
                            Text("pageRotateLeft")
                        } icon: {
                            Image(systemName: "rotate.left")
                        }
                    }
                    
                    Button {
                        pagesModel.rotateRight(adjustedPageIndex)
                    } label: {
                        Label {
                            Text("pageRotateRight")
                        } icon: {
                            Image(systemName: "rotate.right")
                        }
                    }
                }
                
                Section {
                    ForEach(Array(UIApplication.shared.openSessions), id: \.self) { session in
                        if session.url != scene.session.url, let filename = session.url?.lastPathComponent {
                            Button {
                                if let page = pagesModel.pdf.page(at: adjustedPageIndex) {
                                    var timer: Timer? = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                                        session.addPages([page])
                                    }
                                    UIApplication.shared.requestSceneSessionActivation(session, userActivity: nil, options: nil) { _ in
                                        timer?.invalidate()
                                        timer = nil
                                    }
                                }
                            } label: {
                                Label {
                                    Text(String(format: NSLocalizedString("addPageToOpenDoc", comment: ""), filename))
                                } icon: {
                                    Image(systemName: "plus.rectangle.portrait")
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        pagesModel.delete(adjustedPageIndex)
                    } label: {
                        Label {
                            Text("pageDelete")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        
        private func createThumbnail(width: Double, pageIndex: Int) -> some View {
            pagesModel.changeWidth(width)
            
            var adjustedPageIndex = pageIndex
            if let externalDropFakePageIndex, pageIndex > externalDropFakePageIndex {
                adjustedPageIndex -= 1
            }

            return VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageIndex: adjustedPageIndex, tapped: {
                    withAnimation(.linear(duration: 0.1)) {
                        if !inSelectionMode {
                            activePageIndex = adjustedPageIndex
                        } else {
                            isSelected[adjustedPageIndex].toggle()
                        }
                    }
                })
                .border(isSelected[adjustedPageIndex] ? .blue : .black, width: isSelected[adjustedPageIndex] ? 2 : 0.5)
                .frame(height: pagesModel.pagesAspectRatio[adjustedPageIndex] * width)
                .overlay {
                    if adjustedPageIndex == activePageIndex {
                        Color.black.opacity(0.2)
                        
                        Menu {
                            menu(adjustedPageIndex: adjustedPageIndex)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 25))
                                .tint(.black)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                .onDrag {
                    return dragItemProvider(pageIndex: adjustedPageIndex)
                }
                .contextMenu {
                    menu(adjustedPageIndex: adjustedPageIndex)
                }

                .padding(.horizontal, 5)
                .padding(.vertical, 5)
                .background(adjustedPageIndex == activePageIndex ? Color(white: 0.8) : .clear)
                .cornerRadius(4)
                
                Spacer(minLength: 0)
                
                Text("\(adjustedPageIndex + 1)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isSelected[adjustedPageIndex] ? Color.blue : Color.black)
                    .clipShape(Capsule())
                    .padding(.top, 5)
            }
            .onDrop(of: PDFThumbnailsViewController.supportedDroppedItemProviders, delegate: ThumbnailDropDelegate(pageIndex: pageIndex, externalDropFakePageIndex: $externalDropFakePageIndex, dropped: self.handleDropItemProviders))
            //.id(pageIDs[adjustedPageIndex])
        }
        
        private struct Thumbnail: View {
            @StateObject private var pagesModel: PDFPagesModel
            let pageIndex: Int
            let tapped: () -> Void
            
            init(pagesModel: PDFPagesModel, pageIndex: Int, tapped: @escaping () -> Void) {
                _pagesModel = StateObject(wrappedValue: pagesModel)
                self.pageIndex = pageIndex
                self.tapped = tapped
                
                pagesModel.fetchThumbnail(pageIndex: pageIndex)
            }
            
            var body: some View {
                if pageIndex < pagesModel.images.count { // This is false when the pages is deleted from context menu
                    if let image = pagesModel.images[pageIndex] {
                        Image(uiImage: image)
                            .onTapGesture(perform: tapped)
                    } else {
                        Color.gray.opacity(0.5)
                    }
                }
            }
        }
    }
}

extension PDFThumbnailsViewController.PDFThumbnails {
    private static let dropAnimationDuration = 0.1
    
    struct ThumbnailDropDelegate: DropDelegate {
        let pageIndex: Int
        @Binding var externalDropFakePageIndex: Int?
        let dropped: ([NSItemProvider]) -> Void

        func dropUpdated(info: DropInfo) -> DropProposal? {
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                externalDropFakePageIndex = pageIndex
            }
            return DropProposal(operation: .copy)
        }
        
        func performDrop(info: DropInfo) -> Bool {
            let itemProviders = info.itemProviders(for: PDFThumbnailsViewController.supportedDroppedItemProviders)
            dropped(itemProviders)
            return true
        }
    }
    
    struct ScrollViewDropDelegate: DropDelegate {
        let pageIndex: Int
        @Binding var externalDropFakePageIndex: Int?
        let dropped: ([NSItemProvider]) -> Void
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard externalDropFakePageIndex == nil else { return DropProposal(operation: .copy) }
            
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                externalDropFakePageIndex = pageIndex
            }
            
            return DropProposal(operation: .copy)
        }

        func dropExited(info: DropInfo) {
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                externalDropFakePageIndex = nil
            }
        }
        
        func performDrop(info: DropInfo) -> Bool {
            let itemProviders = info.itemProviders(for: PDFThumbnailsViewController.supportedDroppedItemProviders)
            dropped(itemProviders)
            return true
        }
    }

}
