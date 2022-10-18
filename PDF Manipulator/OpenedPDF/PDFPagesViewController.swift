//
//  PDFPagesViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI
import PDFKit
import QuickLook

final class PDFPagesViewController: UIHostingController<PDFPagesViewController.OuterPDFMainView> {
    let pdfDoc: PDFDocument
    let scene: UIWindowScene
    private var presentationManager: PresentationManager?
    
    init(pdfDoc: PDFDocument, scene: UIWindowScene) {
        self.pdfDoc = pdfDoc
        self.scene = scene
        
        super.init(rootView: OuterPDFMainView(pdfDoc: pdfDoc, scene: scene, pdfPagesVC: nil))
        
        self.rootView = OuterPDFMainView(pdfDoc: pdfDoc, scene: scene, pdfPagesVC: self)        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func showSidebar(presentSideBarInteractively: Bool) {
        let thumbnailVC = PDFThumbnailsViewController(pdfDoc: pdfDoc, scene: scene)
        thumbnailVC.modalPresentationStyle = .custom
        self.presentationManager = PresentationManager(presentInteractively: presentSideBarInteractively)
        thumbnailVC.transitioningDelegate = self.presentationManager
        self.present(thumbnailVC, animated: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.horizontalSizeClass == .compact && self.traitCollection.horizontalSizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad {
            self.presentedViewController?.dismiss(animated: false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let screenEdgePanGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(panGestureTriggered))
        screenEdgePanGesture.edges = .right
        screenEdgePanGesture.delegate = self
        self.view.addGestureRecognizer(screenEdgePanGesture)
        
        // Always show the navigation bar not just when scrolled.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemThickMaterial)
        appearance.shadowColor = UIColor(white: 180.0/255, alpha: 1)
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    @objc private func panGestureTriggered(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            self.showSidebar(presentSideBarInteractively: true)
        } else if gesture.state == .changed {
            let pt = gesture.translation(in: gesture.view)
            let toVCFrame = self.transitionCoordinator?.view(forKey: .to)?.frame ?? .zero
            self.presentationManager?.percentDrivenAnimator.update(CGFloat.interpolate(initialX: 0, initialY: 0, finalX: -toVCFrame.width, finalY: 1, currentX: pt.x))
        } else if gesture.state == .cancelled || gesture.state == .ended {
            let panGestureVelocityX = gesture.velocity(in: gesture.view).x
            let isSwipe = panGestureVelocityX < -300

            if gesture.state == .cancelled || (!isSwipe && (self.presentationManager?.percentDrivenAnimator.percentComplete ?? 0) < 0.5) {
                self.presentationManager?.percentDrivenAnimator.cancel()
                gesture.isEnabled = false
                gesture.isEnabled = true
            } else {
                self.presentationManager?.percentDrivenAnimator.finish()
            }
        }
    }

    struct OuterPDFMainView: View {
        let pdfDoc: PDFDocument
        let scene: UIWindowScene
        unowned let pdfPagesVC: PDFPagesViewController!
        
        var body: some View {
            PDFMainView(pdfDoc: pdfDoc, displayScale: Double(scene.keyWindow?.screen.scale ?? 2.0))
                .environment(\.windowScene, scene)
                .environment(\.parentViewController, pdfPagesVC)
        }
    }
    
    private struct PDFMainView: View {
        let pdfDoc: PDFDocument

        @StateObject private var pagesModel: PDFPagesModel
        @Environment(\.windowScene) private var scene
        @State private var activePageIndex = 0
        @State private var disablePostingActivePageIndexNotification = false
        @State private var hidePrimaryColumn = true
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.parentViewController) private var parentViewController
        
        private static let verticalSpacing = 10.0
        private static let gridPadding = 20.0

        init(pdfDoc: PDFDocument, displayScale: Double) {
            self.pdfDoc = pdfDoc
            let pdfPagesModel = PDFPagesModel(pdf: pdfDoc, displayScale: displayScale)
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
        }
        
        @inline(__always) private var pdfPagesViewController: PDFPagesViewController {
            self.parentViewController as! PDFPagesViewController
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
                    if !(horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone) {
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
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        self.pdfPagesViewController.showQuickLookVC()
                    } label: {
                        Image(systemName: "pencil")
                    }

                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button {
                            UIApplication.activateRecentlyOpenedPDFsScene(requestingScene: scene!)
                        } label: {
                            Image(systemName: "folder")
                        }
                    }

                    if horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone {
                        Button {
                            self.pdfPagesViewController.showSidebar(presentSideBarInteractively: false)
                        } label: {
                            Image(systemName: "sidebar.squares.right")
                        }
                    }
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

// Quick look
extension PDFPagesViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        self.pdfDoc.documentURL! as NSURL
    }
    
    func showQuickLookVC() {
        let qlVC = QLPreviewController()
        qlVC.dataSource = self
        self.present(qlVC, animated: true)
    }
}

extension PDFPagesViewController {
    private final class PresentationManager: NSObject, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {
        private final class PresentationController: UIPresentationController {
            private lazy var backgroundCancelButton = {
                let backgroundCancelButton = UIButton(frame: .zero)
                backgroundCancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
                backgroundCancelButton.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                backgroundCancelButton.backgroundColor = .black
                return backgroundCancelButton
            }()

            override var frameOfPresentedViewInContainerView: CGRect {
                guard let containerView = self.containerView else { return .zero }
                
                let containerBounds = containerView.bounds
                let width = containerBounds.width * 0.66
                return CGRect(x: containerBounds.width - width, y: 0, width: width, height: containerBounds.height)
            }
            
            override func containerViewDidLayoutSubviews() {
                super.containerViewDidLayoutSubviews()

                self.presentedViewController.view.frame = self.frameOfPresentedViewInContainerView
            }
            
            override func presentationTransitionWillBegin() {
                super.presentationTransitionWillBegin()
                
                guard let containerView = self.containerView else { return }

                containerView.addSubview(self.backgroundCancelButton)
                self.backgroundCancelButton.frame = containerView.bounds

                self.backgroundCancelButton.alpha = 0
                self.presentedViewController.transitionCoordinator?.animate { context in
                    UIView.animate(withDuration: context.transitionDuration, delay: 0) {
                        self.backgroundCancelButton.alpha = 0.7
                    }
                }
            }
            
            override func dismissalTransitionWillBegin() {
                super.dismissalTransitionWillBegin()
                
                self.presentedViewController.transitionCoordinator?.animate { context in
                    UIView.animate(withDuration: context.transitionDuration, delay: 0) {
                        self.backgroundCancelButton.alpha = 0
                    }
                }
            }
            
            @objc private func cancelButtonTapped() {
                self.presentedViewController.dismiss(animated: true)
            }
        }
        
        private(set) lazy var percentDrivenAnimator = UIPercentDrivenInteractiveTransition()
        let presentInteractively: Bool
        unowned private var presentedViewController: UIViewController!
        
        init(presentInteractively: Bool) {
            self.presentInteractively = presentInteractively
        }

        func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            self.presentedViewController = presented
            return self
        }
        
        func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            self
        }
        
        func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
            self.presentInteractively ? self.percentDrivenAnimator : nil
        }
        
        func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
            PresentationController(presentedViewController: presented, presenting: presenting)
        }
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            0.35
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            let toVC = transitionContext.viewController(forKey: .to)!
            if toVC.isBeingPresented == true {
                var frame = transitionContext.finalFrame(for: toVC)
                frame.origin.x = transitionContext.containerView.bounds.width
                let toView = transitionContext.view(forKey: .to)!
                toView.frame = frame
                transitionContext.containerView.addSubview(toView)
                
                UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: self.presentInteractively ? .curveLinear : .curveEaseInOut) {
                    toView.frame = transitionContext.finalFrame(for: toVC)
                } completion: { completed in
                    transitionContext.completeTransition(completed && !transitionContext.transitionWasCancelled)
                }
            } else {
                UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: self.presentInteractively ? .curveLinear : .curveEaseInOut) {
                    let fromVC = transitionContext.viewController(forKey: .from)!
                    var frame = transitionContext.initialFrame(for: fromVC)
                    frame.origin.x += frame.width
                    transitionContext.view(forKey: .from)?.frame = frame
                } completion: { completed in
                    transitionContext.completeTransition(completed && !transitionContext.transitionWasCancelled)
                }
            }
        }
    }
}

extension PDFPagesViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        self.traitCollection.horizontalSizeClass  == .compact || UIDevice.current.userInterfaceIdiom == .phone
    }
}
