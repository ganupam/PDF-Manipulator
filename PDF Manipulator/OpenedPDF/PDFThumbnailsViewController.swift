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
        
        var body: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                            ForEach(0 ..< pagesModel.images.count, id: \.self) { pageIndex in
                                createList(width: (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2, pageIndex: pageIndex, isSelected: $isSelected[pageIndex])
                                    .overlay(draggingPageID == self.pageIDs[pageIndex] && dragStarted ? Color.white.opacity(0.5) : Color.clear)
        //                                    .onDrag {
        //                                        draggingPageID = self.pageIDs[pageIndex]
        //                                        let itemProvider = NSItemProvider(item: nil, typeIdentifier: UTType.pdf.identifier)
        //                                        itemProvider.registerObject(of: , visibility: .all, loadHandler: <#T##((NSItemProviderWriting?, Error?) -> Void) -> Progress?#>)
        //                                    }
                            }
                        }
                        .ignoresSafeArea(.all, edges: .top)
                        .padding(Self.gridPadding)
                    }
                    .onDrop(of: [UTType.pdf], isTargeted: nil) { itemProviders in
                        self.handleDropItemProviders(itemProviders)
                        return true
                    }
                }
            }
            .onReceive(pagesModel.$images) { newImages in
                isSelected = Array(repeating: false, count: newImages.count)
                pageIDs.removeAll(keepingCapacity: true)
                for _ in 0 ..< newImages.count {
                    pageIDs.append(UUID())
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pagesModel.images.append(UIImage(systemName: "doc.badge.plus")!)
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
            
            itemProviders.forEach {
                group.enter()
                $0.loadItem(forTypeIdentifier: UTType.pdf.identifier) { (data, error) in
                    defer {
                        group.leave()
                    }
                    
                    guard let url = data as? URL, url.startAccessingSecurityScopedResource() else { return }
                    
                    DispatchQueue.main.sync {
                        urls.append(url)
                        
                        guard let pdf = PDFDocument(url: url) else { return }
                        
                        for i in 0 ..< pdf.pageCount {
                            guard let page = pdf.page(at: i) else { continue }
                            
                            pages.append(page)
                        }
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.pagesModel.appendPages(pages)
                
                urls.forEach {
                    $0.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        private func createList(width: Double, pageIndex: Int, isSelected: Binding<Bool>) -> some View {
            pagesModel.changeWidth(width)
            
            return VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageIndex: pageIndex, isSelected: isSelected)
                    .border(isSelected.wrappedValue ? .blue : .black, width: isSelected.wrappedValue ? 2 : 0.5)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(.gray.opacity(0))
                    .frame(height: pagesModel.pagesAspectRatio[pageIndex] * width)
                
                Spacer(minLength: 0)
                
                Text("\(pageIndex + 1)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isSelected.wrappedValue ? Color.blue : Color.black)
                    .clipShape(Capsule())
                    .padding(.top, 5)
            }
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