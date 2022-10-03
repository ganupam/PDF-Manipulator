//
//  PDFPageThumbnailView.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 9/13/22.
//

import Foundation
import UIKit
import SwiftUI

struct PDFPage: View {
    let pdf: CGPDFDocument
    let pageNumber: UInt
    private(set) var isSelected: Binding<Bool>? = nil
    
    var body: some View {
        PDFPageThumbnailSwiftUIView(pdf: pdf, pageNumber: pageNumber)
            .border((isSelected?.wrappedValue ?? false) ? Color.blue : Color.black, width: (isSelected?.wrappedValue ?? false) ? 3 : 0.5)
            .onTapGesture {
                withAnimation(.linear(duration: 0.1)) {
                    isSelected?.wrappedValue.toggle()
                }
            }
    }
}

private struct PDFPageThumbnailSwiftUIView: UIViewRepresentable {
    let pdf: CGPDFDocument
    let pageNumber: UInt

    func makeUIView(context: Context) -> PDFPageThumbnailView {
        PDFPageThumbnailView(pdf: pdf, pageNumber: pageNumber)
    }
    
    func updateUIView(_ uiView: PDFPageThumbnailView, context: Context) {
        
    }
}

final class PDFPageThumbnailView: UIView {
    let pdf: CGPDFDocument
    let pageNumber: UInt
    private let imageView = UIImageView()
    private var currentBounds = CGRect.zero
    private var height = 0.0

    init(pdf: CGPDFDocument, pageNumber: UInt) {
        self.pdf = pdf
        self.pageNumber = pageNumber

        super.init(frame: .zero)
        
        self.addSubview(self.imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard self.currentBounds.width != self.bounds.width else {
            return
        }
        
        self.currentBounds = self.bounds
        self.imageView.frame = self.bounds
        let width = self.bounds.width
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.createThumbnail(width: width)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: height)
    }
    
    private func createThumbnail(width: Double) {
        guard width > 0 else { return }
        
        guard pdf.numberOfPages >= pageNumber else { return }
        
        guard let page = pdf.page(at: Int(pageNumber)) else {
            return
        }
        
        var pageRect = page.getBoxRect(.mediaBox)
        pageRect = pageRect.applying(CGAffineTransform(rotationAngle: Double(page.rotationAngle) * Double.pi / 180))
        pageRect.origin = .zero
        let height = pageRect.height * width / pageRect.width
        pageRect.size.height = height
        self.height = height
        pageRect.size.width = width
        
        let m = page.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.concatenate(m)
            
            ctx.cgContext.drawPDFPage(page)
        }
        
        DispatchQueue.main.async {
            self.invalidateIntrinsicContentSize()
            self.imageView.image = img
        }
    }
}
