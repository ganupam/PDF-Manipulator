//
//  Common.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/6/22.
//

import Foundation
import UniformTypeIdentifiers
import PDFKit

struct Common {
    static let activePageChangedNotification = Notification.Name("activePageChanged")
    static let activePageIndexKey = "activePageIndex"
    static let pdfURLKey = "pdfURL"
    static let supportedDroppedItemProviders = [UTType.pdf, UTType.jpeg, UTType.gif, UTType.bmp, UTType.png, UTType.tiff]
    
    static func pdfPages(from url: URL, typeIdentifier: UTType) -> [PDFPage] {
        guard url.startAccessingSecurityScopedResource() else { return [] }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        switch typeIdentifier {
        case .pdf:
            guard let pdf = PDFDocument(url: url) else { return [] }
            
            var pages = [PDFPage]()
            for i in 0 ..< pdf.pageCount {
                guard let page = pdf.page(at: i) else { continue }
                
                pages.append(page)
            }
            
            return pages
            
        case .jpeg, .png, .tiff, .gif, .bmp:
            // UIImage supports above formats.
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data), let page = PDFPage(image: image) else { return [] }
            
            return [page]
            
        default:
            return []
        }
    }
}

