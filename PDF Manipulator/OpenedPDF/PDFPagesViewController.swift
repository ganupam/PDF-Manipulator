//
//  PDFPagesViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI

final class PDFPagesViewController: UIHostingController<PDFPagesViewController.OuterPDFMainView> {
    let pdfUrl: URL
    
    init(pdfUrl: URL) {
        self.pdfUrl = pdfUrl
        
        super.init(rootView: OuterPDFMainView(pdfUrl: pdfUrl))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct OuterPDFMainView: View {
        let pdfUrl: URL

        var body: some View {
            PDFMainView(pdfUrl: pdfUrl)
                .environment(\.pdfUrl, pdfUrl)
        }
    }
    
    private struct PDFMainView: View {
        let pdfUrl: URL
        @State private var pdfDocument: CGPDFDocument
        @StateObject private var pagesModel: PDFPagesModel
        @Environment(\.windowScene) private var scene: UIWindowScene?

        private static let verticalSpacing = 10.0
        private static let gridPadding = 20.0

        init(pdfUrl: URL) {
            self.pdfUrl = pdfUrl
            let doc = CGPDFDocument(pdfUrl as CFURL)!
            _pdfDocument = State(initialValue: doc)
            let pdfPagesModel = PDFPagesModel(pdf: doc, enableLogging: true)
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
        }

        var body: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ScrollViewWithDidScroll { offset in
                        
                    } content: {
                        LazyVStack(spacing: Self.verticalSpacing) {
                            ForEach(1 ..< (pdfDocument.numberOfPages + 1), id: \.self) { pageNumber in
                                createList(width: (reader.size.width - (Self.gridPadding * 2)), pageNumber: pageNumber)
                            }
                        }
                        .ignoresSafeArea(.all, edges: .top)
                        .padding([.horizontal, .bottom], Self.gridPadding)
                        .padding(.top, Self.gridPadding - 12)
                    }
                    .background(.gray)
                }
            }
            .navigationTitle("\(pdfUrl.lastPathComponent)")
            .navigationBarTitleDisplayMode(.inline)
        }
        
        private func createList(width: Double, pageNumber: Int) -> some View {
            pagesModel.changeWidth(width)
            
            return VStack(spacing: 4) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageNumber: pageNumber)
                    .border(.black, width: 0.5)
                
                Spacer(minLength: 0)                
            }
        }
        
        private struct Thumbnail: View {
            @StateObject private var pagesModel: PDFPagesModel
            let pageNumber: Int
            
            init(pagesModel: PDFPagesModel, pageNumber: Int) {
                _pagesModel = StateObject(wrappedValue: pagesModel)
                self.pageNumber = pageNumber
                
                pagesModel.fetchThumbnail(pageNumber: pageNumber)
            }
            
            var body: some View {
                if let image = pagesModel.images[pageNumber - 1] {
                    Image(uiImage: image)
                } else {
                    Color.gray.opacity(0.5)
                        .frame(height: 200)
                }
            }
        }
    }
}
