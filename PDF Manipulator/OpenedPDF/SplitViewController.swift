//
//  MainViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit
import PDFKit

final class SplitViewController: UISplitViewController {
    let scene: UIWindowScene
    
    init(scene: UIWindowScene) {
        self.scene = scene
        
        super.init(style: .doubleColumn)
        
        self.setViewController(PDFThumbnailsViewController(pdfDoc: scene.session.pdfDoc!, scene: scene), for: .primary)
        
        let vc = PDFPagesViewController(pdfDoc: scene.session.pdfDoc!, scene: scene)
        let navVC = UINavigationController(rootViewController: vc)
        self.setViewController(navVC, for: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }    
}
