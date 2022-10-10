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
        @State private var dropFakePageIndex: Int? = nil

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
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                            ForEach(0 ..< pagesModel.images.count + ((dropFakePageIndex != nil) ? 1 : 0), id: \.self) { pageIndex in
                                if pageIndex == dropFakePageIndex {
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
                    .onDrop(of: PDFThumbnailsViewController.supportedDroppedItemProviders, delegate: ScrollViewDropDelegate(dropFakePageIndex: $dropFakePageIndex, dropped: self.handleDropItemProviders))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: PDFPagesModel.willInsertPages)) { notification in
                guard let indices = notification.userInfo?[PDFPagesModel.pagesInsertionIndicesKey] as? [Int] else { return }
                
                for index in indices {
                    isSelected.insert(false, at: index)
                    pageIDs.insert(UUID(), at: index)
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
        
        private func handleDropItemProviders(_ itemProviders: [NSItemProvider], insertionIndex: Int) {
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
                self.pagesModel.insertPages(pages, at: insertionIndex)
                
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
        
        private func createThumbnail(width: Double, pageIndex: Int) -> some View {
            pagesModel.changeWidth(width)
            
            var adjustedPageIndex = pageIndex
            if let dropFakePageIndex, pageIndex > dropFakePageIndex {
                adjustedPageIndex -= 1
            }

            return VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageIndex: adjustedPageIndex, isSelected: $isSelected[adjustedPageIndex])
                    .border(isSelected[adjustedPageIndex] ? .blue : .black, width: isSelected[adjustedPageIndex] ? 2 : 0.5)
                    .onDrag {
                        return dragItemProvider(pageIndex: adjustedPageIndex)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .frame(height: pagesModel.pagesAspectRatio[adjustedPageIndex] * width)

                
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
            .onDrop(of: PDFThumbnailsViewController.supportedDroppedItemProviders, delegate: ThumbnailDropDelegate(pageIndex: pageIndex, dropFakePageIndex: $dropFakePageIndex, dropped: self.handleDropItemProviders))
        }
        
        private struct Thumbnail: View {
            @StateObject private var pagesModel: PDFPagesModel
            let pageIndex: Int
            @Binding var isSelected: Bool
            
            init(pagesModel: PDFPagesModel, pageIndex: Int, isSelected: Binding<Bool>) {
                _pagesModel = StateObject(wrappedValue: pagesModel)
                self.pageIndex = pageIndex
                _isSelected = isSelected
                
                pagesModel.fetchThumbnail(pageIndex: pageIndex)
            }
            
            var body: some View {
                if let image = pagesModel.images[pageIndex] {
                    Image(uiImage: image)
                        .onTapGesture {
                            withAnimation(.linear(duration: 0.1)) {
                                isSelected.toggle()
                            }
                        }
                } else {
                    Color.gray.opacity(0.5)
                }
            }
        }
    }
}

extension PDFThumbnailsViewController.PDFThumbnails {
    private static let dropAnimationDuration = 0.1
    
    struct ThumbnailDropDelegate: DropDelegate {
        let pageIndex: Int
        @Binding var dropFakePageIndex: Int?
        let dropped: ([NSItemProvider], Int) -> Void

        func dropUpdated(info: DropInfo) -> DropProposal? {
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                dropFakePageIndex = pageIndex
            }
            return DropProposal(operation: .copy)
        }
        
        func performDrop(info: DropInfo) -> Bool {
            let insertionIndex = dropFakePageIndex ?? 0

            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                dropFakePageIndex = nil
            }

            let itemProviders = info.itemProviders(for: PDFThumbnailsViewController.supportedDroppedItemProviders)
            dropped(itemProviders, insertionIndex)
            return true
        }
    }
    
    struct ScrollViewDropDelegate: DropDelegate {
        @Binding var dropFakePageIndex: Int?
        let dropped: ([NSItemProvider], Int) -> Void
        
        func dropExited(info: DropInfo) {
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                dropFakePageIndex = nil
            }
        }
        
        func performDrop(info: DropInfo) -> Bool {
            let insertionIndex = dropFakePageIndex ?? 0
            
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                dropFakePageIndex = nil
            }
            
            let itemProviders = info.itemProviders(for: PDFThumbnailsViewController.supportedDroppedItemProviders)
            dropped(itemProviders, insertionIndex)
            return true
        }
    }

}
