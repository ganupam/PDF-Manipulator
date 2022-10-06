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
    
    init(pdfUrl: URL, scene: UIWindowScene) {
        self.pdfUrl = pdfUrl
        self.scene = scene
        
        super.init(style: .doubleColumn)
        
        self.setViewController(PDFThumbnailsViewController(pdfUrl: pdfUrl, scene: scene), for: .primary)
        self.setViewController(PDFPagesViewController(pdfUrl: pdfUrl), for: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
