//
//  PDFPagesViewController.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 10/5/22.
//

import Foundation
import SwiftUI

final class PDFPagesViewController: UIHostingController<PDFPagesViewController.OuterPDFMainView> {
    let pdfUrl: URL
    
    init(pdfUrl: URL) {
        self.pdfUrl = pdfUrl
        
        super.init(rootView: OuterPDFMainView(pdfUrl: pdfUrl))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct OuterPDFMainView: View {
        let pdfUrl: URL

        var body: some View {
            PDFMainView()
                .environment(\.pdfUrl, pdfUrl)
        }
    }
    
    private struct PDFMainView: View {
        @Environment(\.pdfUrl) private var pdfUrl: URL

        var body: some View {
            Text(verbatim: "PDF Pages")
                .navigationTitle("\(pdfUrl.lastPathComponent)")
        }
    }
}
