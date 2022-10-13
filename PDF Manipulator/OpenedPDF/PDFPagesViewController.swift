//
//  PDFPagesViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI
import PDFKit

final class PDFPagesViewController: UIHostingController<PDFPagesViewController.OuterPDFMainView> {
    let pdfDoc: PDFDocument
    let scene: UIWindowScene
    
    init(pdfDoc: PDFDocument, scene: UIWindowScene) {
        self.pdfDoc = pdfDoc
        self.scene = scene
        
        super.init(rootView: OuterPDFMainView(pdfDoc: pdfDoc, scene: scene))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func showSidebar() {
        let thumbnailVC = PDFThumbnailsViewController(pdfDoc: pdfDoc, scene: scene)
        thumbnailVC.modalPresentationStyle = .custom
        thumbnailVC.transitioningDelegate = self
        self.present(thumbnailVC, animated: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.horizontalSizeClass == .compact && self.traitCollection.horizontalSizeClass == .regular {
            self.presentedViewController?.dismiss(animated: false)
        }
    }

    struct OuterPDFMainView: View {
        let pdfDoc: PDFDocument
        let scene: UIWindowScene

        var body: some View {
            PDFMainView(pdfDoc: pdfDoc, displayScale: Double(scene.keyWindow?.screen.scale ?? 2.0))
                .environment(\.windowScene, scene)
        }
    }
    
    private struct PDFMainView: View {
        let pdfDoc: PDFDocument

        @StateObject private var pagesModel: PDFPagesModel
        @Environment(\.windowScene) private var scene: UIWindowScene?
        @State private var activePageIndex = 0
        @State private var disablePostingActivePageIndexNotification = false
        @State private var hidePrimaryColumn = true
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass

        private static let verticalSpacing = 10.0
        private static let gridPadding = 20.0

        init(pdfDoc: PDFDocument, displayScale: Double) {
            self.pdfDoc = pdfDoc
            let pdfPagesModel = PDFPagesModel(pdf: pdfDoc, displayScale: displayScale)
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
        }

        var body: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ScrollViewReader { scrollReader in
                        ScrollView {
                            LazyVStack(spacing: Self.verticalSpacing) {
                                ForEach(0 ..< pdfDoc.pageCount, id: \.self) { pageIndex in
                                    createList(width: (reader.size.width - (Self.gridPadding * 2)), pageIndex: pageIndex)
                                        .overlay {
                                            GeometryReader { geometry in
                                                Color.clear.preference(
                                                    key: ScrollOffsetPreferenceKey.self,
                                                    value: geometry.frame(in: .named("scrollView")).origin
                                                )
                                            }
                                        }
                                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
                                            guard !disablePostingActivePageIndexNotification, $0.y > 0 && $0.y < reader.size.height / 2 && activePageIndex != pageIndex else { return }

                                            activePageIndex = pageIndex
                                            NotificationCenter.default.post(name: Common.activePageChangedNotification, object: pagesModel, userInfo: [Common.activePageIndexKey : activePageIndex])
                                        }
                                        .id(pageIndex)
                                }
                            }
                            .padding(Self.gridPadding)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: Common.activePageChangedNotification)) { notification in
                            guard let pagesModel = notification.object as? PDFPagesModel, pagesModel !== self.pagesModel, pagesModel.pdf.documentURL == pdfDoc.documentURL, let pageIndex = notification.userInfo?[Common.activePageIndexKey] as? Int else { return }

                            disablePostingActivePageIndexNotification = true
                            withAnimation(.linear(duration: 0.1)) {
                                scrollReader.scrollTo(pageIndex, anchor: UnitPoint(x: 0, y: -0.2))
                            }
                            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                                disablePostingActivePageIndexNotification = false
                            }
                        }
                        .coordinateSpace(name: "scrollView")
                    }
                    .background(.gray)
                }
            }
            .navigationTitle("\(pdfDoc.documentURL?.lastPathComponent ?? "")")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        UIView.animate(withDuration: 0.4) {
                            (scene?.keyWindow?.rootViewController as? SplitViewController)?.preferredDisplayMode = hidePrimaryColumn ? .secondaryOnly : .oneBesideSecondary
                        }
                        withAnimation {
                            hidePrimaryColumn.toggle()
                        }
                    } label: {
                        Image(systemName: hidePrimaryColumn ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                    }
                    .opacity(horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone ? 0 : 1)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        let pdfPagesVC: PDFPagesViewController?
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            pdfPagesVC = ((scene?.keyWindow?.rootViewController as? SplitViewController)?.viewControllers[0] as? UINavigationController)?.topViewController as? PDFPagesViewController
                        } else {
                            pdfPagesVC = (scene?.keyWindow?.rootViewController as? UINavigationController)?.topViewController as? PDFPagesViewController
                        }
                        pdfPagesVC?.showSidebar()
                    } label: {
                        Image(systemName: "sidebar.squares.right")
                    }
                    .opacity(horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone ? 1 : 0)
                }
            }
        }
        
        private func createList(width: Double, pageIndex: Int) -> some View {
            pagesModel.changeWidth(width)
            
            return Thumbnail(pagesModel: pagesModel, pageIndex: pageIndex)
                .border(.black, width: 0.5)
                .frame(height: pagesModel.pagesAspectRatio[pageIndex] * width)
        }
        
        private struct Thumbnail: View {
            @StateObject private var pagesModel: PDFPagesModel
            let pageIndex: Int
            
            init(pagesModel: PDFPagesModel, pageIndex: Int) {
                _pagesModel = StateObject(wrappedValue: pagesModel)
                self.pageIndex = pageIndex
                
                pagesModel.fetchThumbnail(pageIndex: pageIndex)
            }
            
            var body: some View {
                if pageIndex < pagesModel.images.count {
                    if let image = pagesModel.images[pageIndex] {
                        Image(uiImage: image)
                    } else {
                        Color.white
                    }
                }
            }
        }
    }
}

extension PDFPagesViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self
    }
}

extension PDFPagesViewController: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.4
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let toVC = transitionContext.viewController(forKey: .to)!
        if toVC.isBeingPresented == true {
            let bounds = transitionContext.containerView.bounds
            let backgroundCancelButton = UIButton(frame: bounds)
            backgroundCancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
            backgroundCancelButton.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            backgroundCancelButton.backgroundColor = .black
            backgroundCancelButton.alpha = 0
            backgroundCancelButton.tag = 1
            transitionContext.containerView.addSubview(backgroundCancelButton)
            
            var frame = transitionContext.finalFrame(for: toVC)
            frame.origin.x = frame.width
            frame.size.width -= 100
            let toView = transitionContext.view(forKey: .to)!
            toView.frame = frame
            toView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            transitionContext.containerView.addSubview(toView)
            
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
                backgroundCancelButton.alpha = 0.7
                frame.origin.x -= frame.width
                toView.frame = frame
            } completion: { completed in
                transitionContext.completeTransition(completed)
            }
        } else {
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
                let fromVC = transitionContext.viewController(forKey: .from)!
                var frame = transitionContext.initialFrame(for: fromVC)
                transitionContext.containerView.viewWithTag(1)?.alpha = 0
                frame.origin.x += frame.width
                transitionContext.view(forKey: .from)?.frame = frame
            } completion: { completed in
                transitionContext.completeTransition(completed)
            }
        }
    }
    
    @objc private func cancelButtonTapped() {
        self.presentedViewController?.dismiss(animated: true)
    }
}
