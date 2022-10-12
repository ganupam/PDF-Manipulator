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
    static let willInsertPages = Notification.Name("willInsertPages")
    static let willDeletePages = Notification.Name("willDeletePages")
    static let didRotatePage = Notification.Name("didRotatePage")
    static let didExchangePages = Notification.Name("didExchangePages")
    static let pagesIndicesKey = "pagesIndices"
    static let pagesWillInsertKey = "pagesWillInsert"

    private let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".pdfgenerator", qos: .userInitiated, attributes: .concurrent)
    
    private enum ImageGenerationState {
        case notStarted, inProgress, ready
    }
    
    let pdf: PDFDocument
    let displayScale: Double
    let enableLogging: Bool
    
    @Published private(set) var images: [UIImage?]
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
            guard let page = self.pdf.page(at: i) else {
                self.pagesAspectRatio[i] = 0
                continue
            }
            
            let size = page.bounds(for: .mediaBox).size
            let rotationAngle = page.rotation
            self.pagesAspectRatio[i] = ((rotationAngle % 180) == 0) ? (size.height / size.width) : (size.width / size.height)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(willInsertPages), name: Self.willInsertPages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willDeletePages), name: Self.willDeletePages, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didRotatePage), name: Self.didRotatePage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didExchangePages), name: Self.didExchangePages, object: nil)
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
        self.insertPages(pages, at: self.pdf.pageCount)
    }
    
    func insertPages(_ pages: [PDFPage], at index: Int) {
        guard index <= self.pdf.pageCount else { return }
        
        let newPageIndices = (index ..< index + pages.count).map { $0 }
        NotificationCenter.default.post(name: Self.willInsertPages, object: self, userInfo: [Self.pagesIndicesKey : newPageIndices, Self.pagesWillInsertKey : pages])
        
        pages.enumerated().forEach {
            let (i, page) = $0
            pdf.insert(page, at: newPageIndices[i])
        }

        self.updateInternalStateAfterInsertion(pages, indices: newPageIndices)
    }
    
    private func updateInternalStateAfterInsertion(_ pages: [PDFPage], indices: [Int]) {
        guard pages.count == indices.count else { return }
        
        pages.enumerated().forEach {
            let (i, page) = $0
            let size = page.bounds(for: .mediaBox)
            self.pagesAspectRatio.insert(size.height / size.width, at: indices[i])
            self.imageGenerationState.insert(.notStarted, at: indices[i])
            self.images.insert(nil, at: indices[i])
        }
    }
    
    @objc private func willInsertPages(_ notification: NSNotification) {
        guard let otherPDFPagesModel = notification.object as? Self, otherPDFPagesModel !== self, otherPDFPagesModel.pdf.documentURL == self.pdf.documentURL else { return }
        
        guard let pages = notification.userInfo?[Self.pagesWillInsertKey] as? [PDFPage], let indices = notification.userInfo?[Self.pagesIndicesKey] as? [Int] else { return }
        
        self.updateInternalStateAfterInsertion(pages, indices: indices)
    }
    
    @objc private func willDeletePages(_ notification: NSNotification) {
        guard let otherPDFPagesModel = notification.object as? Self, otherPDFPagesModel !== self, otherPDFPagesModel.pdf.documentURL == self.pdf.documentURL else { return }
        
        guard let indices = notification.userInfo?[Self.pagesIndicesKey] as? [Int] else { return }
        
        self.updateInternalStateAfterDeletion(indices)
    }
    
    @objc private func didRotatePage(_ notification: NSNotification) {
        guard let otherPDFPagesModel = notification.object as? Self, otherPDFPagesModel !== self, otherPDFPagesModel.pdf.documentURL == self.pdf.documentURL else { return }
        
        guard let indices = notification.userInfo?[Self.pagesIndicesKey] as? [Int] else { return }
        
        for index in indices {
            self.updateInternalStateAfterRotation(index)
        }
    }

    @objc private func didExchangePages(_ notification: NSNotification) {
        guard let otherPDFPagesModel = notification.object as? Self, otherPDFPagesModel !== self, otherPDFPagesModel.pdf.documentURL == self.pdf.documentURL else { return }
        
        guard let indices = notification.userInfo?[Self.pagesIndicesKey] as? [Int], indices.count == 2 else { return }
        
        self.exchangeImages(index1: indices[0], index2: indices[1])
    }

    @inline(__always) func rotateLeft(_ index: Int) {
        self.rotateLeft([index])
    }
    
    @inline(__always) func rotateRight(_ index: Int) {
        self.rotateRight([index])
    }

    @inline(__always) func rotateLeft(_ indices: [Int]) {
        self.rotate(indices, angle: -90)
    }
    
    @inline(__always) func rotateRight(_ indices: [Int]) {
        self.rotate(indices, angle: 90)
    }
    
    private func rotate(_ indices: [Int], angle: Int) {
        for index in indices {
            guard let page = self.pdf.page(at: index) else { continue }
            
            page.rotation += angle
            self.updateInternalStateAfterRotation(index)
        }
        
        NotificationCenter.default.post(name: Self.didRotatePage, object: self, userInfo: [Self.pagesIndicesKey : indices])
    }
    
    func delete(_ index: Int) {
        self.delete([index])
    }
    
    func delete(_ indices: [Int]) {
        let indices = indices.sorted().reversed()
        
        guard (indices.allSatisfy { $0 < self.pdf.pageCount }) else { return }
        
        NotificationCenter.default.post(name: Self.willDeletePages, object: self, userInfo: [Self.pagesIndicesKey : Array(indices)])

        indices.forEach {
            self.pdf.removePage(at: $0)
        }
        self.updateInternalStateAfterDeletion(Array(indices))
    }
    
    private func updateInternalStateAfterDeletion(_ indices: [Int]) {
        indices.forEach {
            self.pagesAspectRatio.remove(at: $0)
            self.imageGenerationState.remove(at: $0)
            self.images.remove(at: $0)
        }
    }
    
    private func updateInternalStateAfterRotation(_ index: Int) {
        guard let page = self.pdf.page(at: index) else { return }
        
        let size = page.bounds(for: .mediaBox).size
        self.pagesAspectRatio[index] = ((page.rotation % 180) == 0) ? (size.height / size.width) : (size.width / size.height)
        self.imageGenerationState[index] = .notStarted
        self.images[index] = nil
    }
    
    func exchangeImages(index1: Int, index2: Int) {
        let aspectRatio = self.pagesAspectRatio[index1]
        self.pagesAspectRatio[index1] = self.pagesAspectRatio[index2]
        self.pagesAspectRatio[index2] = aspectRatio

        let img = self.images[index1]
        self.images[index1] = self.images[index2]
        self.images[index2] = img
    }
    
    func exchangePages(index1: Int, index2: Int) {
        self.pdf.exchangePage(at: index1, withPageAt: index2)
        
        NotificationCenter.default.post(name: Self.didExchangePages, object: self, userInfo: [Self.pagesIndicesKey : [index1, index2]])
    }
}
