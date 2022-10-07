//
//  MainViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit
import PDFKit

final class SplitViewController: UISplitViewController {
    let pdfUrl: URL
    let scene: UIWindowScene
    private let pdfDoc: PDFDocument
    
    init(pdfUrl: URL, scene: UIWindowScene) {
        self.pdfUrl = pdfUrl
        self.scene = scene
        self.pdfDoc = PDFDocument(url: pdfUrl)!
        
        super.init(style: .doubleColumn)
        
        self.setViewController(PDFThumbnailsViewController(pdfDoc: pdfDoc, scene: scene), for: .primary)
        
        let vc = PDFPagesViewController(pdfDoc: pdfDoc, scene: scene)
        let navVC = UINavigationController(rootViewController: vc)
        self.setViewController(navVC, for: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }    
}
