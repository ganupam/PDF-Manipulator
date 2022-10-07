//
//  PDFThumbnailsViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI

final class PDFThumbnailsViewController: UIHostingController<PDFThumbnailsViewController.OuterPDFThumbnailView> {
    let pdfDoc: CGPDFDocument
    let scene: UIWindowScene
    
    init(pdfDoc: CGPDFDocument, scene: UIWindowScene) {
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
        let pdfDoc: CGPDFDocument
        let scene: UIWindowScene
        
        var body: some View {
            PDFThumbnails(pdfDoc: pdfDoc)
                .environment(\.windowScene, scene)
        }
    }
    
    struct PDFThumbnails: View {
        let pdfDoc: CGPDFDocument
        @State private var isSelected: [Bool]
        @StateObject private var pagesModel: PDFPagesModel
        @Environment(\.windowScene) private var scene: UIWindowScene?
        
        private static let horizontalSpacing = 10.0
        private static let verticalSpacing = 15.0
        private static let gridPadding = 15.0
        
        init(pdfDoc: CGPDFDocument) {
            self.pdfDoc = pdfDoc
            _isSelected = State(initialValue: Array(repeating: false, count: pdfDoc.numberOfPages))
            let pdfPagesModel = PDFPagesModel(pdf: pdfDoc)
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
        }
        
        var body: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                            ForEach(1 ..< (pdfDoc.numberOfPages + 1), id: \.self) { pageNumber in
                                createList(width: (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2, pageNumber: pageNumber, isSelected: $isSelected[pageNumber - 1])
                            }
                        }
                        .ignoresSafeArea(.all, edges: .top)
                        .padding(Self.gridPadding)
                    }
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
            //.navigationBarItems(leading: L)
        }
        
        private func createList(width: Double, pageNumber: Int, isSelected: Binding<Bool>) -> some View {
            pagesModel.changeWidth(width)
            
            return VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageNumber: pageNumber, isSelected: isSelected)
                    .border(isSelected.wrappedValue ? .blue : .black, width: isSelected.wrappedValue ? 2 : 0.5)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(.gray.opacity(0))
                
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
