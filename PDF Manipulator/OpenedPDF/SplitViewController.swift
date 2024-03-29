//
//  MainViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit
import PDFKit

final class SplitViewController: UISplitViewController {
    unowned let scene: UIWindowScene
    private lazy var pagesNavVC = {
        let vc = PDFPagesViewController(pdfManager: scene.session.pdfManager!, scene: scene)
        return UINavigationController(rootViewController: vc)
    }()
    private lazy var thumbnailVC = PDFThumbnailsViewController(pdfManager: scene.session.pdfManager!, scene: scene)
    
    init(scene: UIWindowScene) {
        self.scene = scene
        
        super.init(nibName: nil, bundle: nil)

        self.viewControllers = [self.thumbnailVC, self.pagesNavVC]
        self.preferredDisplayMode = .oneBesideSecondary
        self.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }    
}

extension SplitViewController: UISplitViewControllerDelegate {
    func primaryViewController(forCollapsing splitViewController: UISplitViewController) -> UIViewController? {
        self.pagesNavVC
    }
    
    func primaryViewController(forExpanding splitViewController: UISplitViewController) -> UIViewController? {
        self.thumbnailVC
    }
}
