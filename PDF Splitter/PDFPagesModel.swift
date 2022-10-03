//
//  PDFPagesModel.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 10/3/22.
//

import Foundation
import CoreGraphics
import UIKit

final class PDFPagesModel: ObservableObject {
    private let queue = DispatchQueue(label: "com.pdfgenerator", qos: .userInitiated, attributes: .concurrent)
    
    private enum ImageGenerationState {
        case notStarted, inProgress, ready
    }
    
    let pdf: CGPDFDocument
    @Published private(set) var images: [UIImage?]
    private var imageGenerationState: [ImageGenerationState]
    private var currentWidth = 0.0
    
    init(pdf: CGPDFDocument) {
        self.pdf = pdf
        self.images = Array(repeating: nil, count: pdf.numberOfPages)
        self.imageGenerationState = Array(repeating: .notStarted, count: pdf.numberOfPages)
    }
    
    func changeWidth(_ width: Double) {
        DispatchQueue.main.async {
            guard self.currentWidth != width else { return}
            
            print("Changed width from \(self.currentWidth) to \(width)")
            
            self.currentWidth = width
            
            self.imageGenerationState = Array(repeating: .notStarted, count: self.pdf.numberOfPages)
            self.images = Array(repeating: nil, count: self.pdf.numberOfPages)
        }
    }
    
    func fetchThumbnail(pageNumber: Int) {
        guard self.currentWidth > 0 else { return }
        
        for i in (pageNumber ..< min(pageNumber + 3, pdf.numberOfPages + 1)) {
            guard self.imageGenerationState[i - 1] == .notStarted else { return }
            
            self.imageGenerationState[i - 1] = .inProgress
          
            self.queue.async {
                let img = self.createThumbnail(pageNumber: i)
                
                DispatchQueue.main.sync {
                    self.imageGenerationState[i - 1] = .ready
                    self.images[i - 1] = img
                }
            }
        }
    }
    
    private func createThumbnail(pageNumber: Int) -> UIImage? {
        guard pdf.numberOfPages >= pageNumber, let page = pdf.page(at: pageNumber) else {
            return nil
        }
        
        print("\(Unmanaged.passUnretained(self).toOpaque()), Page number:", pageNumber, ", width:", self.currentWidth)
        var pageRect = page.getBoxRect(.mediaBox)
        pageRect = pageRect.applying(CGAffineTransform(rotationAngle: Double(page.rotationAngle) * Double.pi / 180))
        pageRect.origin = .zero
        let height = pageRect.height * self.currentWidth / pageRect.width
        pageRect.size.height = height
        pageRect.size.width = self.currentWidth
        
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
        return img
    }
}
