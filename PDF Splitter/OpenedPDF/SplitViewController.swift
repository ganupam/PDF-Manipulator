//
//  MainViewController.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit

final class SplitViewController: UISplitViewController {
    let pdfUrl: URL
    
    init(pdfUrl: URL) {
        self.pdfUrl = pdfUrl

        super.init(style: .doubleColumn)
        
        self.setViewController(PDFThumbnailsViewController(pdfUrl: pdfUrl), for: .primary)
        self.setViewController(PDFPagesViewController(pdfUrl: pdfUrl), for: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
