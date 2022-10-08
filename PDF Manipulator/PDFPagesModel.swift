//
//  PDFPagesModel.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/3/22.
//

import Foundation
import UIKit
import PDFKit

final class PDFPagesModel: ObservableObject {
    private let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".pdfgenerator", qos: .userInitiated, attributes: .concurrent)
    
    private enum ImageGenerationState {
        case notStarted, inProgress, ready
    }
    
    let pdf: PDFDocument
    let displayScale: Double
    let enableLogging: Bool
    
    @Published var images: [UIImage?]
    private var imageGenerationState: [ImageGenerationState]
    private(set) var pagesAspectRatio: [Double]
    private var currentWidth = 0.0
    
    init(pdf: PDFDocument, displayScale: Double, enableLogging: Bool = false) {
        self.pdf = pdf
        self.displayScale = displayScale
        self.enableLogging = enableLogging
        self.images = Array(repeating: nil, count: pdf.pageCount)
        self.imageGenerationState = Array(repeating: .notStarted, count: pdf.pageCount)
        self.pagesAspectRatio = Array(repeating: 0.0, count: self.pdf.pageCount)
        for i in (0 ..< self.pdf.pageCount) {
            guard let size = self.pdf.page(at: i)?.bounds(for: .mediaBox).size else {
                self.pagesAspectRatio[i] = 0
                continue
            }
            
            self.pagesAspectRatio[i] = size.height / size.width
        }
    }
    
    func changeWidth(_ width: Double) {
        DispatchQueue.main.async {
            guard self.currentWidth != width else { return}
            
            if self.enableLogging {
                print("Changed width from \(self.currentWidth) to \(width)")
            }
            
            self.currentWidth = width
            
            self.imageGenerationState = Array(repeating: .notStarted, count: self.pdf.pageCount)
            self.images = Array(repeating: nil, count: self.pdf.pageCount)
        }
    }
    
    func fetchThumbnail(pageIndex: Int) {
        guard self.currentWidth > 0 else { return }
        
        for i in (pageIndex ..< min(pageIndex + 3, pdf.pageCount)) {
            guard self.imageGenerationState[i] == .notStarted else { return }
            
            self.imageGenerationState[i] = .inProgress
          
            self.queue.async {
                let img = self.createThumbnail(pageIndex: i)
                
                DispatchQueue.main.sync {
                    self.imageGenerationState[i] = .ready
                    self.images[i] = img
                }
            }
        }
    }
    
    private func createThumbnail(pageIndex: Int) -> UIImage? {
        guard pdf.pageCount > pageIndex, let page = pdf.page(at: pageIndex) else {
            return nil
        }
        
        if enableLogging {
            print("\(Unmanaged.passUnretained(self).toOpaque()), Page index:", pageIndex, ", width:", self.currentWidth)
        }

        let bounds = page.bounds(for: .mediaBox)
        let img = page.thumbnail(of: CGSize(width: self.currentWidth * self.displayScale, height: bounds.height * self.currentWidth / bounds.width * self.displayScale), for: .mediaBox)
        
        guard let imgCGImage = img.cgImage else { return nil }
        
        return UIImage(cgImage: imgCGImage, scale: self.displayScale, orientation: .up)
    }
    
    func appendPages(_ pages: [PDFPage]) {
        var newPageIndices = [Int]()
        pages.forEach {
            let size = $0.bounds(for: .mediaBox)
            self.pagesAspectRatio.append(size.height / size.width)
            self.imageGenerationState.append(.notStarted)
            self.images.append(nil)
            pdf.insert($0, at: pdf.pageCount)
            newPageIndices.append(pdf.pageCount)
        }
        
        newPageIndices.forEach {
            self.fetchThumbnail(pageIndex: $0)
        }
    }
}
