//
//  PDFPagesModel.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/3/22.
//

import Foundation
import UIKit
import PDFKit

final class PDFManager: NSObject {
    static let willInsertPages = Notification.Name("willInsertPages")
    static let willDeletePages = Notification.Name("willDeletePages")
    static let didRotatePage = Notification.Name("didRotatePage")
    static let didExchangePages = Notification.Name("didExchangePages")
    static let willReloadPDF = Notification.Name("willReloadPDF")
    static let pagesIndicesKey = "pagesIndices"
    static let pagesWillInsertKey = "pagesWillInsert"

    private var registeredObjects = [UUID : PDFPagesModel]()
    
    private var pdfDoc: PDFDocument
    private(set) var pagesAspectRatio: [Double]
    private var lastModifiedDate: Date
    
    let url: URL
    unowned var scene: UIWindowScene
    
    init?(url: URL, scene: UIWindowScene) {
        guard url.startAccessingSecurityScopedResource() else { return nil }
                
        guard let doc = PDFDocument(url: url) else { url.stopAccessingSecurityScopedResource(); return nil }
    
        self.url = url
        self.pdfDoc = doc
        self.lastModifiedDate = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[FileAttributeKey.modificationDate] as? Date) ?? Date()
        self.pagesAspectRatio = Array(repeating: 0.0, count: self.pdfDoc.pageCount)
        self.scene = scene
        
        super.init()

        self.calculateAspectRatios()

        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEnterBackgroundNotification), name: UIScene.didEnterBackgroundNotification, object: scene)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillEnterForegroundNotification), name: UIScene.willEnterForegroundNotification, object: scene)
    }
    
    @objc private func sceneDidEnterBackgroundNotification() {
        NSFileCoordinator.removeFilePresenter(self)
    }
    
    @objc private func sceneWillEnterForegroundNotification() {
        guard FileManager.default.fileExists(atPath: self.url.path) else {
            UIApplication.shared.requestSceneSessionDestruction(self.scene.session, options: nil)
            return
        }

        NSFileCoordinator.addFilePresenter(self)
    }
    
    private func calculateAspectRatios() {
        self.pagesAspectRatio = Array(repeating: 0.0, count: self.pdfDoc.pageCount)
        for i in (0 ..< self.pdfDoc.pageCount) {
            guard let page = self.pdfDoc.page(at: i) else {
                self.pagesAspectRatio[i] = 0
                continue
            }
            
            let size = page.bounds(for: .mediaBox).size
            let rotationAngle = page.rotation
            self.pagesAspectRatio[i] = ((rotationAngle % 180) == 0) ? (size.height / size.width) : (size.width / size.height)
        }
    }
    
    deinit {
        pdfDoc.documentURL?.stopAccessingSecurityScopedResource()
    }
    
    var pageCount: Int {
        self.pdfDoc.pageCount
    }
    
    func page(at index: Int) -> PDFPage? {
        self.pdfDoc.page(at: index)
    }
    
    func getPDFPagesModel(identifier: UUID, displayScale: Double, enableLogging: Bool = false) -> PDFPagesModel {
        let model = PDFPagesModel(pdf: pdfDoc, displayScale: displayScale, enableLogging: enableLogging)
        registeredObjects[identifier] = model
        return model
    }
    
    private func model(with identifier: UUID) -> PDFPagesModel {
        guard let model = self.registeredObjects[identifier] else {
            preconditionFailure("Model with specified identifier not found.")
        }
        
        return model
    }
    
    func changeWidth(to width: Double, identifier: UUID) {
        self.model(with: identifier).changeWidth(width)
    }
    
    func fetchThumbnail(pageIndex: Int, identifier: UUID) {
        self.model(with: identifier).fetchThumbnail(pageIndex: pageIndex)
    }
    
    @inline(__always) func appendPages(_ pages: [PDFPage]) {
        self.insertPages(pages, at: self.pdfDoc.pageCount)
    }
    
    func insertPages(_ pages: [PDFPage], at index: Int) {
        guard index <= self.pdfDoc.pageCount else { return }
        
        let newPageIndices = (index ..< index + pages.count).map { $0 }
        NotificationCenter.default.post(name: PDFManager.willInsertPages, object: self, userInfo: [PDFManager.pagesIndicesKey : newPageIndices, PDFManager.pagesWillInsertKey : pages])
        
        pages.enumerated().forEach {
            let (i, page) = $0
            let size = page.bounds(for: .mediaBox)
            self.pagesAspectRatio.insert(((page.rotation % 180) == 0) ? (size.height / size.width) : (size.width / size.height), at: newPageIndices[i])
            self.pdfDoc.insert(page, at: newPageIndices[i])
        }

        self.registeredObjects.values.forEach { model in
            model.insertPages(at: newPageIndices)
        }
        
        self.saveChanges()
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
    
    @inline(__always) private func rotate(_ indices: [Int], angle: Int) {
        for index in indices {
            guard let page = self.pdfDoc.page(at: index) else { continue }
            
            page.rotation += angle
            let size = page.bounds(for: .mediaBox).size
            self.pagesAspectRatio[index] = ((page.rotation % 180) == 0) ? (size.height / size.width) : (size.width / size.height)
        }
        
        self.registeredObjects.values.forEach { model in
            model.rotate(indices, angle: angle)
        }
        
        NotificationCenter.default.post(name: PDFManager.didRotatePage, object: self, userInfo: [PDFManager.pagesIndicesKey : indices])
        
        self.saveChanges()
    }
    
    @inline(__always) func delete(_ index: Int) {
        self.delete([index])
    }
    
    func delete(_ indices: [Int]) {
        let indices = indices.sorted().reversed()
        
        guard (indices.allSatisfy { $0 < self.pdfDoc.pageCount }) else { return }
        
        NotificationCenter.default.post(name: PDFManager.willDeletePages, object: self, userInfo: [PDFManager.pagesIndicesKey : Array(indices)])

        indices.forEach {
            self.pagesAspectRatio.remove(at: $0)
            self.pdfDoc.removePage(at: $0)
        }

        self.registeredObjects.values.forEach { model in
            model.delete(Array(indices))
        }
        
        self.saveChanges()
    }
    
    func exchangeImages(index1: Int, index2: Int, identifier: UUID) {
        let aspectRatio = self.pagesAspectRatio[index1]
        self.pagesAspectRatio[index1] = self.pagesAspectRatio[index2]
        self.pagesAspectRatio[index2] = aspectRatio

        self.model(with: identifier).exchangeImages(index1: index1, index2: index2)
    }
    
    func exchangePages(index1: Int, index2: Int, excludePageModelWithIdentifier: UUID) {
        self.pdfDoc.exchangePage(at: index1, withPageAt: index2)
        
        for identifier in self.registeredObjects.keys where identifier != excludePageModelWithIdentifier {
            self.registeredObjects[identifier]?.exchangeImages(index1: index1, index2: index2)
        }
        
        NotificationCenter.default.post(name: PDFManager.didExchangePages, object: self, userInfo: [PDFManager.pagesIndicesKey : [index1, index2]])
        
        self.saveChanges()
    }
    
    private func saveChanges() {
        NSFileCoordinator.removeFilePresenter(self)
        self.pdfDoc.write(to: self.url)
        NSFileCoordinator.addFilePresenter(self)
    }
}

final class PDFPagesModel: ObservableObject {
    private let queue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".pdfgenerator", qos: .userInitiated, attributes: .concurrent)
    
    private enum ImageGenerationState {
        case notStarted, inProgress, ready
    }
    
    fileprivate var pdf: PDFDocument
    let displayScale: Double
    let enableLogging: Bool
    
    @Published private(set) var images: [UIImage?]
    private var imageGenerationState: [ImageGenerationState]
    private var currentWidth = 0.0
    
    fileprivate init(pdf: PDFDocument, displayScale: Double, enableLogging: Bool = false) {
        self.pdf = pdf
        self.displayScale = displayScale
        self.enableLogging = enableLogging
        self.images = Array(repeating: nil, count: pdf.pageCount)
        self.imageGenerationState = Array(repeating: .notStarted, count: pdf.pageCount)
    }
    
    fileprivate func reinitialize() {
        self.images = Array(repeating: nil, count: pdf.pageCount)
        self.imageGenerationState = Array(repeating: .notStarted, count: pdf.pageCount)
    }
    
    fileprivate func changeWidth(_ width: Double) {
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
    
    fileprivate func fetchThumbnail(pageIndex: Int) {
        guard self.currentWidth > 0 else { return }
        
        for i in (pageIndex ..< min(pageIndex + 3, pdf.pageCount)) {
            guard self.imageGenerationState[i] == .notStarted else { return }
            
            self.imageGenerationState[i] = .inProgress
          
            self.queue.async {
                let img = self.createThumbnail(pageIndex: i)
                
                DispatchQueue.main.async {
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
    
    fileprivate func insertPages(at newPageIndices: [Int]) {
        for newPageIndex in newPageIndices {
            self.imageGenerationState.insert(.notStarted, at: newPageIndex)
            self.images.insert(nil, at: newPageIndex)
        }
    }

    fileprivate func rotate(_ indices: [Int], angle: Int) {
        for index in indices {
            self.imageGenerationState[index] = .notStarted
            self.images[index] = nil
        }
    }
    
    fileprivate func delete(_ indices: [Int]) {
        indices.forEach {
            self.imageGenerationState.remove(at: $0)
            self.images.remove(at: $0)
        }
    }
    
    fileprivate func exchangeImages(index1: Int, index2: Int) {
        let img = self.images[index1]
        self.images[index1] = self.images[index2]
        self.images[index2] = img
    }
}

extension PDFManager: NSFilePresenter {
    var presentedItemURL: URL? {
        self.url
    }
    
    var presentedItemOperationQueue: OperationQueue {
        .main
    }
    
    func presentedItemDidChange() {
        var error: NSError? = nil
        NSFileCoordinator().coordinate(readingItemAt: self.url, error: &error) { url in
            guard let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[FileAttributeKey.modificationDate] as? Date, date != self.lastModifiedDate else { return }
            
            self.lastModifiedDate = date
            
            self.reloadPDF(with: url)
        }
    }
    
    func presentedItemDidMove(to newURL: URL) {
        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
        UIApplication.openPDF(newURL, requestingScene: scene)
    }
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
        completionHandler(nil)
    }
    
    func savePresentedItemChanges(completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
    
    private func reloadPDF(with url: URL) {
        guard let pdf = PDFDocument(url: url) else {
            url.stopAccessingSecurityScopedResource()
            return
        }
        
        self.pdfDoc = pdf
        self.calculateAspectRatios()
        
        NotificationCenter.default.post(name: Self.willReloadPDF, object: self)
        
        self.registeredObjects.values.forEach {
            $0.pdf = pdf
            $0.reinitialize()
        }
    }
}
