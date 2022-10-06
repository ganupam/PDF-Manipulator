//
//  PDFThumbnailsViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI

final class PDFThumbnailsViewController: UIHostingController<PDFThumbnailsViewController.OuterPDFThumbnailView> {
    let pdfUrl: URL
    let scene: UIWindowScene
    
    init(pdfUrl: URL, scene: UIWindowScene) {
        self.pdfUrl = pdfUrl
        self.scene = scene
        
        super.init(rootView: OuterPDFThumbnailView(pdfUrl: pdfUrl, scene: scene))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PDFThumbnailsViewController {
    struct OuterPDFThumbnailView: View {
        let pdfUrl: URL
        let scene: UIWindowScene
        
        var body: some View {
            PDFThumbnails(pdfUrl: pdfUrl)
                .environment(\.pdfUrl, pdfUrl)
                .environment(\.windowScene, scene)
        }
    }
    
    struct PDFThumbnails: View {
        @State private var pdfDocument: CGPDFDocument
        @State private var isSelected: [Bool]
        @StateObject private var pagesModel: PDFPagesModel
        @State private var statusBarOverlayOpacity = 1.0
        @Environment(\.windowScene) private var scene: UIWindowScene?
        
        private static let horizontalSpacing = 10.0
        private static let verticalSpacing = 15.0
        private static let gridPadding = 15.0
        
        init(pdfUrl: URL) {
            let doc = CGPDFDocument(pdfUrl as CFURL)!
            _pdfDocument = State(initialValue: doc)
            _isSelected = State(initialValue: Array(repeating: false, count: doc.numberOfPages))
            let pdfPagesModel = PDFPagesModel(pdf: doc)
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
        }
        
        var body: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ZStack(alignment: .top) {
                        ScrollViewWithDidScroll { offset in
                            statusBarOverlayOpacity = Double.interpolate(initialX: 0, initialY: 0, finalX: -20, finalY: 1, currentX: offset.y)
                        } content: {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                                ForEach(1 ..< (pdfDocument.numberOfPages + 1), id: \.self) { pageNumber in
                                    createList(width: (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2, pageNumber: pageNumber, isSelected: $isSelected[pageNumber - 1])
                                }
                            }
                            .ignoresSafeArea(.all, edges: .top)
                            .padding([.horizontal, .bottom], Self.gridPadding)
                            .padding(.top, Self.gridPadding - 12)
                        }
                        
                        Color.clear
                            .background(.ultraThinMaterial)
                            .opacity(statusBarOverlayOpacity)
                            .frame(height: scene?.statusBarManager?.statusBarFrame.height ?? 0)
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea(.all, edges: .top)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        
        private func createList(width: Double, pageNumber: Int, isSelected: Binding<Bool>) -> some View {
            pagesModel.changeWidth(width)
            
            return VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageNumber: pageNumber, isSelected: isSelected)
                    .border(isSelected.wrappedValue ? .blue : .black, width: isSelected.wrappedValue ? 2 : 0.5)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(.gray)
                
                Spacer(minLength: 0)
                
                Text("\(pageNumber)")
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
            let pageNumber: Int
            @Binding var isSelected: Bool
            
            init(pagesModel: PDFPagesModel, pageNumber: Int, isSelected: Binding<Bool>) {
                _pagesModel = StateObject(wrappedValue: pagesModel)
                self.pageNumber = pageNumber
                _isSelected = isSelected
                
                pagesModel.fetchThumbnail(pageNumber: pageNumber)
            }
            
            var body: some View {
                if let image = pagesModel.images[pageNumber - 1] {
                    Image(uiImage: image)
                        .onTapGesture {
                            withAnimation(.linear(duration: 0.1)) {
                                isSelected.toggle()
                            }
                        }
                } else {
                    Color.gray.opacity(0.5)
                        .frame(height: 200)
                }
            }
        }
    }
}
