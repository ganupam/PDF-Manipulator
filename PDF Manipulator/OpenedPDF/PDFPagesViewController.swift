//
//  PDFPagesViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI

final class PDFPagesViewController: UIHostingController<PDFPagesViewController.OuterPDFMainView> {
    let pdfDoc: CGPDFDocument

    init(pdfDoc: CGPDFDocument) {
        self.pdfDoc = pdfDoc
        
        super.init(rootView: OuterPDFMainView(pdfDoc: pdfDoc))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.navigationController?.navigationBar.isTranslucent = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct OuterPDFMainView: View {
        let pdfDoc: CGPDFDocument
   
        var body: some View {
            PDFMainView(pdfDoc: pdfDoc)
        }
    }
    
    private struct PDFMainView: View {
        let pdfDoc: CGPDFDocument

        @StateObject private var pagesModel: PDFPagesModel
        @Environment(\.windowScene) private var scene: UIWindowScene?

        private static let verticalSpacing = 10.0
        private static let gridPadding = 20.0

        init(pdfDoc: CGPDFDocument) {
            self.pdfDoc = pdfDoc
            let pdfPagesModel = PDFPagesModel(pdf: pdfDoc, enableLogging: true)
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
                            ForEach(1 ..< (pdfDoc.numberOfPages + 1), id: \.self) { pageNumber in
                                createList(width: (reader.size.width - (Self.gridPadding * 2)), pageNumber: pageNumber)
                            }
                        }
//                        .ignoresSafeArea(.all, edges: .top)
                        .padding(Self.gridPadding)
                    }
                    .background(.gray)
                }
            }
            .navigationTitle("\(pdfDoc.url?.lastPathComponent ?? "")")
        }
        
        private func createList(width: Double, pageNumber: Int) -> some View {
            pagesModel.changeWidth(width)
            
            return Thumbnail(pagesModel: pagesModel, pageNumber: pageNumber)
                .border(.black, width: 0.5)
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
                        .resizable()
                        .frame(height: 972.5)
                } else {
                    Color.white
                        .frame(height: 200)
                }
            }
        }
    }
}
