//
//  PDFThumbnailsViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

final class PDFThumbnailsViewController: UIHostingController<PDFThumbnailsViewController.OuterPDFThumbnailView> {
    private static let supportedDroppedItemProviders = [UTType.pdf, UTType.jpeg, UTType.gif, UTType.bmp, UTType.png, UTType.tiff]
    
    let pdfDoc: PDFDocument
    let scene: UIWindowScene
    
    init(pdfDoc: PDFDocument, scene: UIWindowScene) {
        self.pdfDoc = pdfDoc
        self.scene = scene
        
        super.init(rootView: OuterPDFThumbnailView(pdfDoc: pdfDoc, scene: scene))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PDFThumbnailsViewController {
    struct OuterPDFThumbnailView: View {
        let pdfDoc: PDFDocument
        let scene: UIWindowScene
        
        var body: some View {
            PDFThumbnails(pdfDoc: pdfDoc, scene: scene)
                .environment(\.windowScene, scene)
        }
    }
    
    struct PDFThumbnails: View {
        let pdfDoc: PDFDocument
        let scene: UIWindowScene
        @State private var isSelected: [Bool]
        @StateObject private var pagesModel: PDFPagesModel
        @State private var pageIDs: [UUID]
        @State private var internalDragPageIndex: Int?
        @State private var currentInternalDropPageIndex: Int?
        @State private var externalDropFakePageIndex: Int? = nil
        @State private var activePageIndex = 0
        @State private var inSelectionMode = false
        @State private var pdfToExport: URL?
        
        private static let horizontalSpacing = 10.0
        private static let verticalSpacing = 15.0
        private static let gridPadding = 15.0
        
        init(pdfDoc: PDFDocument, scene: UIWindowScene) {
            self.pdfDoc = pdfDoc
            self.scene = scene
            _isSelected = State(initialValue: Array(repeating: false, count: pdfDoc.pageCount))
            let pdfPagesModel = PDFPagesModel(pdf: pdfDoc, displayScale: Double(scene.keyWindow?.screen.scale ?? 2.0))
            _pagesModel = StateObject(wrappedValue: pdfPagesModel)
            
            var IDs = [UUID]()
            for _ in 0 ..< pdfDoc.pageCount {
                IDs.append(UUID())
            }
            _pageIDs = State(initialValue: IDs)
        }
        
        private func dragItemProvider(pageIndex: Int) -> NSItemProvider {
            let itemProvider = NSItemProvider()
            itemProvider.suggestedName = self.pdfDoc.documentURL?.lastPathComponent
            itemProvider.registerItem(forTypeIdentifier: UTType.pdf.identifier) { completionHandler, classType, dict in
                guard completionHandler != nil, let pdfName = self.pdfDoc.documentURL?.lastPathComponent, let page = self.pdfDoc.page(at: pageIndex)?.dataRepresentation else {
                    completionHandler?(nil, NSError(domain: "", code: 1))
                    return
                }
                
                let pdfPath = FileManager.default.temporaryDirectory.appendingPathComponent(pdfName)
                
                do {
                    try page.write(to: pdfPath)
                }
                catch {
                    completionHandler?(nil, NSError(domain: "", code: 1))
                    return
                }
                
                completionHandler?(pdfPath as NSSecureCoding, nil)
            }
            return itemProvider
        }
        
        private var vcShownAsSideBar: Bool {
            scene.keyWindow?.traitCollection.horizontalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone
        }
        
        private func dismissSideBar(completion: (() -> Void)? = nil) {
            let pdfThumbnailVC: PDFThumbnailsViewController
            if UIDevice.current.userInterfaceIdiom == .pad {
                pdfThumbnailVC = (scene.keyWindow?.rootViewController as? SplitViewController)?.viewControllers[0].presentedViewController as! PDFThumbnailsViewController
            } else {
                pdfThumbnailVC = scene.keyWindow?.rootViewController?.presentedViewController as! PDFThumbnailsViewController
            }
            pdfThumbnailVC.dismiss(animated: true, completion: completion)
        }

        @ViewBuilder
        private var navBarLeadingButton: some View {
            if vcShownAsSideBar {
                Button {
                    self.dismissSideBar()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }

        private var navBarTrailingButton: some View {
            Button {
                inSelectionMode.toggle()
            } label: {
                Text(NSLocalizedString(inSelectionMode ? "generalDone" : "selectPages", comment: ""))
            }
        }
        
        var body: some View {
            NavigationView {
                if #available(iOS 16, *) {
                    mainBody
                        .toolbar(inSelectionMode ? .visible : .hidden, for: .bottomBar)
                        .toolbar {
                            ToolbarItemGroup(placement: .navigationBarLeading) {
                                navBarLeadingButton
                            }

                            ToolbarItemGroup(placement: .navigationBarTrailing) {
                                navBarTrailingButton
                            }
                        }
                        .animation(.linear(duration: 0.1), value: inSelectionMode)
                } else {
                    mainBody
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(leading:navBarLeadingButton, trailing: navBarTrailingButton)
                }
            }
        }
        
        private func copyPagesSubmenu(pageIndices: [Int]) -> some View {
            let recentlyOpenedURLs = RecentlyOpenFilesManager.sharedInstance.urls.filter { url in
                url != self.pdfDoc.documentURL
            }.prefix(5)
            
            return Group {
                Section {
                    Button {
                        guard let tmpPDFUrl = self.createTmpPDF(pageIndices: pageIndices) else { return }
                        
                        pdfToExport = tmpPDFUrl
                    } label: {
                        Label {
                            Text("savePagesAsNewDocument")
                        } icon: {
                            Image(systemName: "doc.badge.plus")
                        }
                    }
                }

                Section {
                    Button {

                    } label: {
                        Label {
                            Text("addSelectedPagesToExistingPDF")
                        } icon: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                }
                
                Section("addSelectedPagesToRecentFiles") {
                    ForEach(recentlyOpenedURLs, id: \.self) { url in
                        Button {
                            
                        } label: {
                            Label {
                                Text(url.lastPathComponent)
                            } icon: {
                                Image(systemName: "plus.rectangle.portrait")
                            }
                        }
                    }
                }
            }
        }
        
        private var mainBody: some View {
            GeometryReader { reader in
                if reader.size.width == 0 {
                    EmptyView()
                } else {
                    ScrollViewReader { scrollReader in
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                                ForEach(0 ..< pagesModel.images.count + ((externalDropFakePageIndex != nil) ? 1 : 0), id: \.self) { pageIndex in
                                    if pageIndex == externalDropFakePageIndex {
                                        VStack(spacing: 0) {
                                            Color.gray.opacity(0.5)
                                                .border(.black, width: 0.5)
                                                .frame(height: 1.29 * (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2)
                                            
                                            Spacer()
                                        }
                                    } else {
                                        createThumbnail(width: (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing - 10) / 2, pageIndex: pageIndex)
                                    }
                                }
                            }
                            .ignoresSafeArea(.all, edges: .top)
                            .padding(Self.gridPadding)
                        }
                        .onDrop(of: PDFThumbnailsViewController.supportedDroppedItemProviders, delegate: ScrollViewDropDelegate(pageIndex:pagesModel.images.count, internalDragPageIndex: $internalDragPageIndex, externalDropFakePageIndex: $externalDropFakePageIndex, dropped: self.handleDropItemProviders))
                        .onReceive(NotificationCenter.default.publisher(for: Common.activePageChangedNotification)) { notification in
                            guard let pagesModel = notification.object as? PDFPagesModel, pagesModel !== self.pagesModel, pagesModel.pdf.documentURL == pdfDoc.documentURL, let pageIndex = notification.userInfo?[Common.activePageIndexKey] as? Int else { return }

                            withAnimation(.linear(duration: 0.1)) {
                                scrollReader.scrollTo(pageIDs[pageIndex])
                                activePageIndex = pageIndex
                            }
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: PDFPagesModel.willInsertPages)) { notification in
                guard (notification.object as? PDFPagesModel)?.pdf.documentURL == pdfDoc.documentURL else { return }
                
                guard let indices = notification.userInfo?[PDFPagesModel.pagesIndicesKey] as? [Int] else { return }
                
                for index in indices {
                    isSelected.insert(false, at: index)
                    pageIDs.insert(UUID(), at: index)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: PDFPagesModel.willDeletePages)) { notification in
                guard (notification.object as? PDFPagesModel)?.pdf.documentURL == pdfDoc.documentURL else { return }

                guard let indices = notification.userInfo?[PDFPagesModel.pagesIndicesKey] as? [Int] else { return }
                
                for index in indices {
                    isSelected.remove(at: index)
                    pageIDs.remove(at: index)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if inSelectionMode {
                        Menu {
                            copyPagesSubmenu(pageIndices: isSelected.enumerated().compactMap { $0.1 ? $0.0 : nil })
                        } label: {
                            Image(systemName: "doc.badge.plus")
                        }
                        .disabled(isSelected.firstIndex(of: true) == nil)
                        
                        Button {
                            pagesModel.rotateLeft(isSelected.enumerated().compactMap { $0.1 ? $0.0 : nil } )
                        } label: {
                            Image(systemName: "rotate.left")
                        }
                        .disabled(isSelected.firstIndex(of: true) == nil)
                        
                        Button {
                            pagesModel.rotateRight(isSelected.enumerated().compactMap { $0.1 ? $0.0 : nil } )
                        } label: {
                            Image(systemName: "rotate.right")
                        }
                        .disabled(isSelected.firstIndex(of: true) == nil)
                        
                        Button {
                            self.deletePagesWithConfirmation(isSelected.enumerated().compactMap { $0.1 ? $0.0 : nil })
                        } label: {
                            Image(systemName: "trash")
                                .renderingMode(.template)
                                .tint(.red)
                        }
                        .disabled(isSelected.firstIndex(of: true) == nil)
                    }
                }
            }
            .sheet(isPresented: .constant(pdfToExport != nil)) {
                FilePickerView(operationMode: .export(urlsToExport: [pdfToExport!])) { url in
                    try? FileManager.default.removeItem(at: pdfToExport!)
                    
                    pdfToExport = nil
                    
                    
                    guard let url else { return }
                    
                    func openPDF() {
                        for i in 0 ..< isSelected.count {
                            isSelected[i] = false
                        }
                        withAnimation {
                            inSelectionMode = false
                        }
                        
                        UIApplication.openPDF(url, requestingScene: self.scene)
                    }
                    
                    if vcShownAsSideBar {
                        self.dismissSideBar(completion: openPDF)
                    } else {
                        openPDF()
                    }
                }
            }
        }
        
        private func deletePagesWithConfirmation(_ indices: [Int]) {
            let alert = UIAlertController(title: nil, message: String(format: NSLocalizedString("deletePagesConfirmationTitle", comment: ""), indices.count), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("generalDelete", comment: ""), style: .destructive) { _ in
                pagesModel.delete(indices)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("generalCancel", comment: ""), style: .cancel))
            var VC = scene.keyWindow?.rootViewController
            if let presented = VC?.presentedViewController {
                VC = presented
            }
            VC?.present(alert, animated: true)
        }
        
        private func createTmpPDF(pageIndices: [Int]) -> URL? {
            let pdf = PDFDocument()
            
            var insertionIndex = 0
            pageIndices.forEach {
                guard let page = self.pdfDoc.page(at: $0) else {
                    return
                }
                
                pdf.insert(page, at: insertionIndex)
                insertionIndex += 1
            }
            
            let filename = self.pdfDoc.documentURL!.deletingPathExtension().lastPathComponent
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename).appendingPathExtension("pdf")
            
            guard pdf.write(to: url) else {
                UIAlertController.show(message: NSLocalizedString("errorUnableToCreateFile", comment: ""), defaultButtonTitle: NSLocalizedString("generalOK", comment: ""), scene: scene)
                return nil
            }
            
            return url
        }
        
        private func handleDropItemProviders(_ itemProviders: [NSItemProvider]) {
            var pages = [PDFPage]()
            var urls = [URL]()
            let group = DispatchGroup()
            
            itemProviders.forEach { itemProvider in
                guard let typeIdentifier = (PDFThumbnailsViewController.supportedDroppedItemProviders.first {
                    itemProvider.registeredTypeIdentifiers.contains($0.identifier)
                }) else { return }
                
                group.enter()
                itemProvider.loadItem(forTypeIdentifier: typeIdentifier.identifier) { (data, error) in
                    defer {
                        group.leave()
                    }
                    
                    guard let url = data as? URL, url.startAccessingSecurityScopedResource() else { return }
                    
                    DispatchQueue.main.sync {
                        urls.append(url)
                        
                        pages.append(contentsOf: self.pdfPages(from: url, typeIdentifier: typeIdentifier))
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.pagesModel.insertPages(pages, at: externalDropFakePageIndex ?? 0)
                self.externalDropFakePageIndex = nil
                
                urls.forEach {
                    $0.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        private func pdfPages(from url: URL, typeIdentifier: UTType) -> [PDFPage] {
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
        
        private func menu(adjustedPageIndex: Int) -> some View {
            Group {
                Section {
                    Button {
                        pagesModel.rotateLeft(adjustedPageIndex)
                    } label: {
                        Label {
                            Text("pageRotateLeft")
                        } icon: {
                            Image(systemName: "rotate.left")
                        }
                    }
                    
                    Button {
                        pagesModel.rotateRight(adjustedPageIndex)
                    } label: {
                        Label {
                            Text("pageRotateRight")
                        } icon: {
                            Image(systemName: "rotate.right")
                        }
                    }
                }
                
                copyPagesSubmenu(pageIndices: [adjustedPageIndex])
                
                Section {
                    Button(role: .destructive) {
                        self.deletePagesWithConfirmation([adjustedPageIndex])
                    } label: {
                        Label {
                            Text("pageDelete")
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        
        private func createThumbnail(width: Double, pageIndex: Int) -> some View {
            pagesModel.changeWidth(width)
            
            var adjustedPageIndex = pageIndex
            if let externalDropFakePageIndex, pageIndex > externalDropFakePageIndex {
                adjustedPageIndex -= 1
            }

            return VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                Thumbnail(pagesModel: pagesModel, pageIndex: adjustedPageIndex, tapped: {
                    withAnimation(.linear(duration: 0.1)) {
                        if !inSelectionMode {
                            activePageIndex = adjustedPageIndex
                            NotificationCenter.default.post(name: Common.activePageChangedNotification, object: pagesModel, userInfo: [Common.activePageIndexKey : activePageIndex])
                        } else {
                            isSelected[adjustedPageIndex].toggle()
                        }
                    }
                })
                .border(inSelectionMode && isSelected[adjustedPageIndex] ? .blue : .black, width: inSelectionMode && isSelected[adjustedPageIndex] ? 2 : 0.5)
                .frame(height: pagesModel.pagesAspectRatio[adjustedPageIndex] * width)
                .overlay {
                    if !inSelectionMode && adjustedPageIndex == activePageIndex {
                        Color.black.opacity(0.2)
                        
                        Menu {
                            menu(adjustedPageIndex: adjustedPageIndex)
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 25))
                                .tint(.white)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                .onDrag({
                    internalDragPageIndex = adjustedPageIndex
                    return dragItemProvider(pageIndex: adjustedPageIndex)
                }, preview: {
                    Thumbnail(pagesModel: pagesModel, pageIndex: adjustedPageIndex, tapped: {})
                        .border(.black, width: 0.5)
                        .frame(height: pagesModel.pagesAspectRatio[adjustedPageIndex] * width)
                })
                .contextMenus(menuItems: {
                    menu(adjustedPageIndex: adjustedPageIndex)
                }, preview: {
                    Thumbnail(pagesModel: pagesModel, pageIndex: adjustedPageIndex, tapped: {})
                        .frame(height: pagesModel.pagesAspectRatio[adjustedPageIndex] * width)
                })
                .padding(.horizontal, 5)
                .padding(.vertical, 5)
                .background(!inSelectionMode && adjustedPageIndex == activePageIndex ? Color(white: 0.8) : .clear)
                .cornerRadius(4)
                .id(pageIDs[adjustedPageIndex])

                Spacer(minLength: 0)
                
                Text("\(adjustedPageIndex + 1)")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(inSelectionMode && isSelected[adjustedPageIndex] ? Color.blue : Color(white: 0.3))
                    .clipShape(Capsule())
                    .padding(.top, 5)
            }
            .opacity(adjustedPageIndex == currentInternalDropPageIndex ? 0.01 : 1)
            .onDrop(of: PDFThumbnailsViewController.supportedDroppedItemProviders, delegate: ThumbnailDropDelegate(pagesModel: pagesModel, pageIndex: pageIndex, internalDragPageIndex: $internalDragPageIndex, currentInternalDropPageIndex: $currentInternalDropPageIndex, externalDropFakePageIndex: $externalDropFakePageIndex, dropped: self.handleDropItemProviders))
        }
        
        private struct Thumbnail: View {
            @StateObject private var pagesModel: PDFPagesModel
            let pageIndex: Int
            let tapped: () -> Void
            
            init(pagesModel: PDFPagesModel, pageIndex: Int, tapped: @escaping () -> Void) {
                _pagesModel = StateObject(wrappedValue: pagesModel)
                self.pageIndex = pageIndex
                self.tapped = tapped
                
                pagesModel.fetchThumbnail(pageIndex: pageIndex)
            }
            
            var body: some View {
                if pageIndex < pagesModel.images.count { // This is false when the pages is deleted from context menu
                    if let image = pagesModel.images[pageIndex] {
                        Image(uiImage: image)
                            .onTapGesture(perform: tapped)
                    } else {
                        Color.gray.opacity(0.5)
                    }
                }
            }
        }
    }
}

extension PDFThumbnailsViewController.PDFThumbnails {
    private static let dropAnimationDuration = 0.1
    
    struct ThumbnailDropDelegate: DropDelegate {
        @ObservedObject var pagesModel: PDFPagesModel
        let pageIndex: Int
        @Binding var internalDragPageIndex: Int?
        @Binding var currentInternalDropPageIndex: Int?
        @Binding var externalDropFakePageIndex: Int?
        let dropped: ([NSItemProvider]) -> Void

        func dropEntered(info: DropInfo) {
            guard let internalDragPageIndex else {
                return
            }
            
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                pagesModel.exchangeImages(index1: internalDragPageIndex, index2: pageIndex)
                currentInternalDropPageIndex = pageIndex
            }
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard internalDragPageIndex == nil else {
                return DropProposal(operation: .move)
            }

            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                externalDropFakePageIndex = pageIndex
            }
            return DropProposal(operation: .copy)
        }
        
        func dropExited(info: DropInfo) {
            guard let internalDragPageIndex else {
                return
            }
            
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                pagesModel.exchangeImages(index1: internalDragPageIndex, index2: pageIndex)
                currentInternalDropPageIndex = nil
            }
        }
        
        func performDrop(info: DropInfo) -> Bool {
            if let internalDragPageIndex {
                pagesModel.exchangePages(index1: internalDragPageIndex, index2: pageIndex)
                currentInternalDropPageIndex = nil
                self.internalDragPageIndex = nil
            } else {
                let itemProviders = info.itemProviders(for: PDFThumbnailsViewController.supportedDroppedItemProviders)
                dropped(itemProviders)
            }
            return true
        }
    }
    
    struct ScrollViewDropDelegate: DropDelegate {
        let pageIndex: Int
        @Binding var internalDragPageIndex: Int?
        @Binding var externalDropFakePageIndex: Int?
        let dropped: ([NSItemProvider]) -> Void
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard internalDragPageIndex == nil else {
                return DropProposal(operation: .move)
            }

            guard externalDropFakePageIndex == nil else { return DropProposal(operation: .copy) }
                
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                externalDropFakePageIndex = pageIndex
            }
            
            return DropProposal(operation: .copy)
        }

        func dropExited(info: DropInfo) {
            guard internalDragPageIndex == nil else {
                return
            }
            
            withAnimation(.linear(duration: PDFThumbnailsViewController.PDFThumbnails.dropAnimationDuration)) {
                externalDropFakePageIndex = nil
            }
        }
        
        func performDrop(info: DropInfo) -> Bool {
            if internalDragPageIndex != nil {
                self.internalDragPageIndex = nil
                return false
            } else {
                let itemProviders = info.itemProviders(for: PDFThumbnailsViewController.supportedDroppedItemProviders)
                dropped(itemProviders)
                return true
            }
        }
    }

}
