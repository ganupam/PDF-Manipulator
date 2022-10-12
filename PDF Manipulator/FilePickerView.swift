//
//  FilePickerView.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 9/13/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: UIViewControllerRepresentable {
    let selectableContentTypes: [UTType]
    let documentPicked: (URL?) -> Void
    
    final class FilePickerViewDelegate: NSObject, UIDocumentPickerDelegate {
        let documentPicked: (URL?) -> Void

        init(documentPicked: @escaping (URL?) -> Void) {
            self.documentPicked = documentPicked
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            self.documentPicked(nil)
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            self.documentPicked(urls.first)
        }
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: self.selectableContentTypes)
        documentPicker.shouldShowFileExtensions = true
        documentPicker.delegate = context.coordinator
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // TODO
    }
    
    func makeCoordinator() -> FilePickerViewDelegate {
        FilePickerViewDelegate(documentPicked: self.documentPicked)
    }
}
