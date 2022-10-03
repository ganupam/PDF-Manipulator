//
//  MainViewController.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 8/26/22.
//

import UIKit
import SwiftUI

final class MainViewController: UIHostingController<MainViewController.MainView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(rootView: MainView())
        
        if let documentFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            print("Documents folder: ", documentFolder)
        }
    }
}

extension MainViewController {
    struct MainView: View {
        @State private var pdfPath: URL? = nil
        
        var body: some View {
            Group {
                if let pdfPath {
                    NavigationView {
                        Sidebar()
                        
                        PDFThumbnails(pdfPath: pdfPath)
                        
                        PDFMainView()
                    }
                } else {
                    NavigationView {
                        Sidebar()
                        
                        PDFMainView()
                    }
                }
            }
            .environment(\.pdfUrl, $pdfPath)
        }
    }
}

struct Sidebar: View {
    var body: some View {
        Text("Sidebar")
    }
}

struct PDFThumbnails: View {
    let pdfPath: URL
    
    @State private var pdfDocument: CGPDFDocument
    @State private var isSelected: [Bool]
    @StateObject private var pagesModel: PDFPagesModel
    
    init(pdfPath: URL) {
        self.pdfPath = pdfPath
        
        let doc = CGPDFDocument(pdfPath as CFURL)!
        _pdfDocument = State(initialValue: doc)
        _isSelected = State(initialValue: Array(repeating: false, count: doc.numberOfPages))
        _pagesModel = StateObject(wrappedValue: PDFPagesModel(pdf: doc))
    }

    var body: some View {
        GeometryReader { reader in
            createList(width: reader.size.width)
        }        
    }
    
    private func createList(width: Double) -> some View {
        if width == 0 {
            return AnyView(EmptyView())
        }
        
        pagesModel.changeWidth(width - 20 * 2)
        
        return AnyView(ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(1 ..< (pdfDocument.numberOfPages + 1), id: \.self) {
                    Thumbnail(pagesModel: pagesModel, pageNumber: $0)
                        .border(.black)
                        .padding(.horizontal, 20)
                }
            }
        })
    }
    
    private struct Thumbnail: View {
        @StateObject private var pagesModel: PDFPagesModel
        let pageNumber: Int
        
        init(pagesModel: PDFPagesModel, pageNumber: Int) {
            _pagesModel = StateObject(wrappedValue: pagesModel)
            self.pageNumber = pageNumber
            
            pagesModel.fetchThumbnail(pageNumber: pageNumber)
        }
        
        var body: some View {
            if let image = pagesModel.images[pageNumber - 1] {
                Image(uiImage: image)
            } else {
                Text("Loading...")
                    .frame(height: 400)
            }
        }
    }
}

struct PDFMainView: View {
    @State private var showingFilePicker = false
    @State private var title = "PDF Splitter"
    @Environment(\.pdfUrl) @Binding var pdfPath: URL?

    var body: some View {
        Text(verbatim: "Main View")
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadTestPDF()
                        //showingFilePicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePickerView { url in
                    
                }
            }
    }
    
    private func loadTestPDF() {
        guard let pdfPath = Bundle.main.url(forResource: "Test", withExtension: "pdf") else {
            assertionFailure("Test.pdf not found.")
            return
        }
        
        self.title = pdfPath.absoluteString
        self.pdfPath = pdfPath
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainViewController.MainView()
            .previewDisplayName("hasOpenedPDF: false")
    }
}
