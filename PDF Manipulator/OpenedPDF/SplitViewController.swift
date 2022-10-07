//
//  MainViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit

final class SplitViewController: UISplitViewController {
    let pdfUrl: URL
    let scene: UIWindowScene
    private let pdfDoc: CGPDFDocument
    
    init(pdfUrl: URL, scene: UIWindowScene) {
        self.pdfUrl = pdfUrl
        self.scene = scene
        self.pdfDoc = CGPDFDocument(pdfUrl as CFURL)!
        self.pdfDoc.url = pdfUrl
        
        super.init(style: .doubleColumn)
        
        self.setViewController(PDFThumbnailsViewController(pdfDoc: pdfDoc, scene: scene), for: .primary)
        
        let vc = PDFPagesViewController(pdfDoc: pdfDoc)
        let navVC = UINavigationController(rootViewController: vc)
        self.setViewController(navVC, for: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }    
}
