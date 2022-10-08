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


struct GridData: Identifiable, Equatable {
    let id: Int
}

//MARK: - Model

class Model: ObservableObject {
    @Published var data: [GridData]

    let columns = [
        GridItem(.fixed(160)),
        GridItem(.fixed(160))
    ]

    init() {
        data = Array(repeating: GridData(id: 0), count: 100)
        for i in 0..<data.count {
            data[i] = GridData(id: i)
        }
    }
}

//MARK: - Grid

struct DemoDragRelocateView: View {
    @StateObject private var model = Model()

    @State private var dragging: GridData?
    @State private var dragStarted = false

    var body: some View {
        ScrollView {
           LazyVGrid(columns: model.columns, spacing: 32) {
                ForEach(model.data) { d in
                    GridItemView(d: d)
                        .overlay(dragging?.id == d.id && dragStarted ? Color.white.opacity(0.8) : Color.clear)
                        .onDrag {
                            self.dragging = d
                            return NSItemProvider(object: String(d.id) as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: DragRelocateDelegate(item: d, listData: $model.data, current: $dragging, dragStarted: $dragStarted))
                }
            }.animation(.default, value: model.data)
        }
        .onDrop(of: [UTType.text], delegate: DropOutsideDelegate(current: $dragging))
    }
}

struct DragRelocateDelegate: DropDelegate {
    let item: GridData
    @Binding var listData: [GridData]
    @Binding var current: GridData?
    @Binding var dragStarted: Bool

    func dropEntered(info: DropInfo) {
        if item != current {
            dragStarted = true
            
            let from = listData.firstIndex(of: current!)!
            let to = listData.firstIndex(of: item)!
            if listData[to].id != current!.id {
                listData.move(fromOffsets: IndexSet(integer: from),
                    toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        self.dragStarted = false
        self.current = nil
        return true
    }
}

//MARK: - GridItem

struct GridItemView: View {
    var d: GridData

    var body: some View {
        VStack {
            Text(String(d.id))
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 160, height: 240)
        .background(Color.green)
    }
}

struct DropOutsideDelegate: DropDelegate {
    @Binding var current: GridData?
        
    func performDrop(info: DropInfo) -> Bool {
        current = nil
        return true
    }
}

struct d: PreviewProvider {
    static var previews: some View {
        DemoDragRelocateView()
    }
}
