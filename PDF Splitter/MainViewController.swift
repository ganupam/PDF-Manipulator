//
//  MainViewController.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

final class MainViewController: UISplitViewController {
    let pdfUrlPublisher = CurrentValueSubject<URL?, Never>(nil)
}

final class PDFThumbnailsViewController: UIHostingController<PDFThumbnailsViewController.OuterPDFThumbnailView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(rootView: PDFThumbnailsViewController.OuterPDFThumbnailView())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rootView = PDFThumbnailsViewController.OuterPDFThumbnailView(pdfUrlPublisher: (self.splitViewController as! MainViewController).pdfUrlPublisher)
    }
}

extension PDFThumbnailsViewController {
    struct OuterPDFThumbnailView: View {
        private(set) var pdfUrlPublisher: CurrentValueSubject<URL?, Never>? = nil

        @State private var pdfUrl: URL?
        
        var body: some View {
            if let pdfUrlPublisher {
                Group {
                    if let pdfUrl {
                        PDFThumbnails(pdfPath: pdfUrl)
                    } else {
                        Text("Open a PDF")
                    }
                }
                .onReceive(pdfUrlPublisher) {
                    pdfUrl = $0
                }
            } else {
                Text("Open a PDF")
            }
        }
    }
}

struct PDFThumbnails: View {
    let pdfPath: URL
    
    @State private var pdfDocument: CGPDFDocument
    @State private var isSelected: [Bool]
    @StateObject private var pagesModel: PDFPagesModel
    
    private static let horizontalSpacing = 20.0
    private static let verticalSpacing = 20.0
    private static let gridPadding = 20.0

    init(pdfPath: URL) {
        self.pdfPath = pdfPath
        
        let doc = CGPDFDocument(pdfPath as CFURL)!
        _pdfDocument = State(initialValue: doc)
        _isSelected = State(initialValue: Array(repeating: false, count: doc.numberOfPages))
        let pdfPagesModel = PDFPagesModel(pdf: doc)
        _pagesModel = StateObject(wrappedValue: pdfPagesModel)
    }

    var body: some View {
        GeometryReader { reader in
            if reader.size.width == 0 {
                EmptyView()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Self.horizontalSpacing), GridItem(.flexible())], spacing: Self.verticalSpacing) {
                        ForEach(1 ..< (pdfDocument.numberOfPages + 1), id: \.self) { pageNumber in
                            createList(width: (reader.size.width - (Self.gridPadding * 2) - Self.horizontalSpacing) / 2, pageNumber: pageNumber, isSelected: $isSelected[pageNumber - 1])
                        }
                    }
                    .padding(Self.gridPadding)
                }
            }
        }
    }
    
    private func createList(width: Double, pageNumber: Int, isSelected: Binding<Bool>) -> some View {
        pagesModel.changeWidth(width)
        
        return VStack(spacing: 4) {
            Spacer(minLength: 0)
            
            Thumbnail(pagesModel: pagesModel, pageNumber: pageNumber, isSelected: isSelected)
                .border(isSelected.wrappedValue ? .blue : .black, width: isSelected.wrappedValue ? 2 : 0.5)
            
            Spacer(minLength: 0)

            Text("\(pageNumber)")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected.wrappedValue ? Color.blue : Color.black)
                .clipShape(Capsule())
        }
    }
    
    private struct Thumbnail: View {
        @StateObject private var pagesModel: PDFPagesModel
        let pageNumber: Int
        @Binding var isSelected: Bool
        
        init(pagesModel: PDFPagesModel, pageNumber: Int, isSelected: Binding<Bool>) {
            _pagesModel = StateObject(wrappedValue: pagesModel)
            self.pageNumber = pageNumber
            _isSelected = isSelected
            
            pagesModel.fetchThumbnail(pageNumber: pageNumber)
        }
        
        var body: some View {
            if let image = pagesModel.images[pageNumber - 1] {
                Image(uiImage: image)
                    .onTapGesture {
                        withAnimation(.linear(duration: 0.1)) {
                            isSelected.toggle()
                        }
                    }
            } else {
                Color.gray.opacity(0.5)
                    .frame(height: 200)
            }
        }
    }
}

final class PDFPagesViewController: UIHostingController<PDFPagesViewController.OuterPDFMainView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(rootView: OuterPDFMainView())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rootView = OuterPDFMainView(pdfUrlPublisher: (self.splitViewController as! MainViewController).pdfUrlPublisher)
    }

    struct OuterPDFMainView: View {
        private(set) var pdfUrlPublisher: CurrentValueSubject<URL?, Never>? = nil
        
        @State private var pdfUrl: URL?
        
        var body: some View {
            if let pdfUrlPublisher {
                PDFMainView(pdfUrlPublisher: pdfUrlPublisher)
                    .onReceive(pdfUrlPublisher) {
                        pdfUrl = $0
                    }
            } else {
                Text("Open a PDF")
            }
        }
    }
    
    private struct PDFMainView: View {
        let pdfUrlPublisher: CurrentValueSubject<URL?, Never>
        
        @State private var showingFilePicker = false

        var body: some View {
            Text(verbatim: "Main View")
                .navigationTitle("PDF Splitter")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            //loadTestPDF()
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
                .sheet(isPresented: $showingFilePicker) {
                    FilePickerView(selectableContentTypes: [UTType.pdf]) { url in
                        guard url != nil else { return }
                        
                        let userActivity = NSUserActivity(activityType: .openPDFUserActivityType)
                        userActivity.userInfo = ["url" : url as Any]
                        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
                        //self.pdfUrlPublisher.value = url
                    }
                }
        }
        
        private func loadTestPDF() {
            guard let pdfPath = Bundle.main.url(forResource: "Test", withExtension: "pdf") else {
                assertionFailure("Test.pdf not found.")
                return
            }
            
            self.pdfUrlPublisher.value = pdfPath
        }
    }
}
