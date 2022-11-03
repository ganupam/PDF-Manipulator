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
    let pdfManager: PDFManager
    unowned let scene: UIWindowScene
    
    private var presentationManager: PresentationManager?
    
    init(pdfManager: PDFManager, scene: UIWindowScene) {
        self.pdfManager = pdfManager
        self.scene = scene
        
        super.init(rootView: OuterPDFMainView(pdfManager: pdfManager, scene: scene, pdfPagesVC: nil))
        
        self.rootView = OuterPDFMainView(pdfManager: pdfManager, scene: scene, pdfPagesVC: self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func showSidebar(presentSideBarInteractively: Bool) {
        let thumbnailVC = PDFThumbnailsViewController(pdfManager: pdfManager, scene: scene)
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
        let pdfManager: PDFManager
        unowned let scene: UIWindowScene
        unowned let pdfPagesVC: PDFPagesViewController?
        
        var body: some View {
            PDFMainView(scene: scene, parentViewController: pdfPagesVC, pdfManager: pdfManager, displayScale: Double(scene.keyWindow?.screen.scale ?? 2.0))
        }
    }
    
    private struct PDFMainView: View {
        let pdfManager: PDFManager
        unowned let scene: UIWindowScene
        unowned let parentViewController: UIViewController?

        @StateObject private var pagesModel: PDFPagesModel
        @State private var activePageIndex = 0
        @State private var disablePostingActivePageIndexNotification = false
        @State private var hidePrimaryColumn = true
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @State private var identifier: UUID
        @State private var scaleFactor = 1.0
        @State private var previousScaleFactor = 1.0
        @State private var showDocumentPicker = false
        @State private var adSize = CGSize.zero
        @State private var showAd = (StoreKitManager.InAppPurchaseProduct.adRemoval.purchaseState != .purchased)

        private static let verticalSpacing = 10.0
        private static let gridPadding = (UIDevice.current.userInterfaceIdiom == .phone ? 10.0 : 20.0)
        
        init(scene: UIWindowScene, parentViewController: UIViewController?, pdfManager: PDFManager, displayScale: Double) {
            self.scene = scene
            self.parentViewController = parentViewController
            self.pdfManager = pdfManager
            let uuid = UUID()
            _identifier = State(initialValue: uuid)
            let pdfPagesModel = pdfManager.getPDFPagesModel(identifier: uuid, displayScale: displayScale)
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
        }
        
        @inline(__always) private var pdfPagesViewController: PDFPagesViewController {
            self.parentViewController as! PDFPagesViewController
        }

        var body: some View {
            GeometryReader { reader in
                VStack(spacing: 0) {
                    if reader.size.width != 0 {
                        ScrollViewReader { scrollReader in
                            ScrollView(scaleFactor == 1.0 ? .vertical : [.horizontal, .vertical], showsIndicators: scaleFactor == 1.0) {
                                LazyVStack(spacing: Self.verticalSpacing) {
                                    ForEach(0 ..< pdfManager.pageCount, id: \.self) { pageIndex in
                                        createList(width: (reader.size.width - (Self.gridPadding * 2)), pageIndex: pageIndex)
                                            .frame(width: (reader.size.width - (Self.gridPadding * 2)) * scaleFactor, height: pdfManager.pagesAspectRatio[pageIndex] * (reader.size.width - (Self.gridPadding * 2)) * scaleFactor)
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
                                                NotificationCenter.default.post(name: Common.activePageChangedNotification, object: identifier, userInfo: [Common.activePageIndexKey : activePageIndex, Common.pdfURLKey : self.pdfManager.url])
                                            }
                                            .id(pageIndex)
                                    }
                                }
                                .padding(Self.gridPadding)
                            }
                            .gesture(MagnificationGesture().onChanged { newValue in
                                scaleFactor = max(previousScaleFactor * newValue, 1)
                            }.onEnded { _ in
                                previousScaleFactor = scaleFactor
                            })
                            .onReceive(NotificationCenter.default.publisher(for: Common.activePageChangedNotification)) { notification in
                                guard notification.object as? UUID != self.identifier, notification.userInfo?[Common.pdfURLKey] as? URL == self.pdfManager.url, let pageIndex = notification.userInfo?[Common.activePageIndexKey] as? Int else { return }
                                
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
                        .onReceive(NotificationCenter.default.publisher(for: StoreKitManager.purchaseStateChanged)) { _ in
                            showAd = (StoreKitManager.InAppPurchaseProduct.adRemoval.purchaseState != .purchased)
                        }
                    }
                    
                    if showAd {
                        GoogleADBannerView(adUnitID: "ca-app-pub-5089136213554560/4047719008", scene: scene, rootViewController: parentViewController!, availableWidth: reader.size.width) { size in
                            adSize = size
                        }
                        .frame(width: adSize.width, height: adSize.height)
                        .frame(maxWidth: reader.size.width)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                FilePickerView(operationMode: .open(selectableContentTypes: Common.supportedDroppedItemProviders)) { url in
                    guard let url, let type = UTType(tag: url.pathExtension, tagClass: .filenameExtension, conformingTo: nil) else { return }
                    
                    let pages = Common.pdfPages(from: url, typeIdentifier: type)
                    
                    self.pdfManager.insertPages(pages, at: self.pdfManager.pageCount)
                }
            }
            .navigationTitle("\(pdfManager.url.lastPathComponent)")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !(horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone) {
                        Button {
                            UIView.animate(withDuration: 0.4) {
                                (scene.keyWindow?.rootViewController as? SplitViewController)?.preferredDisplayMode = hidePrimaryColumn ? .secondaryOnly : .oneBesideSecondary
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

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Image(systemName: "plus.rectangle.portrait")
                    }

                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Button {
                            UIApplication.activateRecentlyOpenedPDFsScene(requestingScene: scene)
                        } label: {
                            Image(systemName: "clock")
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
            pdfManager.changeWidth(to: width, identifier: self.identifier)
            
            return Thumbnail(pdfManager: pdfManager, pagesModel: pagesModel, pageIndex: pageIndex, identifier: self.identifier)
                .border(.black, width: 0.5)
        }
        
        private struct Thumbnail: View {
            let pdfManager: PDFManager
            @ObservedObject private var pagesModel: PDFPagesModel
            let pageIndex: Int
            let identifier: UUID

            init(pdfManager: PDFManager, pagesModel: PDFPagesModel, pageIndex: Int, identifier: UUID) {
                self.pdfManager = pdfManager
                _pagesModel = ObservedObject(wrappedValue: pagesModel)
                self.pageIndex = pageIndex
                self.identifier = identifier
                
                pdfManager.fetchThumbnail(pageIndex: pageIndex, identifier: identifier)
            }
            
            var body: some View {
                if pageIndex < pagesModel.images.count {
                    if let image = pagesModel.images[pageIndex] {
                        Image(uiImage: image)
                            .resizable()
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
        self.pdfManager.url as NSURL
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
