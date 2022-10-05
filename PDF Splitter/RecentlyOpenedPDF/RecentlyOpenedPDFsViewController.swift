//
//  RecentlyOpenedPDFsViewController.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 10/4/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class RecentlyOpenedPDFsViewController: UIHostingController<RecentlyOpenedPDFsViewController.RecentlyOpenedPDFsView> {
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    
    init() {
        super.init(rootView: RecentlyOpenedPDFsView())
        
        if let documentFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            print("Documents folder: ", documentFolder)
        }
    }
    
    struct RecentlyOpenedPDFsView: View {
        @State private var showingFilePicker = false

        var body: some View {
            Text(verbatim: "Main View")
                .navigationTitle("PDF Splitter")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "folder")
                        }
                    }
                }
                .sheet(isPresented: $showingFilePicker) {
                    FilePickerView(selectableContentTypes: [UTType.pdf]) { url in
                        guard let url else { return }
                        
                        let session = UIApplication.shared.openSessions.first {
                            $0.userInfo?["url"] as? String == url.absoluteString
                        }
                        
                        let userActivity = NSUserActivity(activityType: .openPDFUserActivityType)
                        userActivity.userInfo = ["url" : url.absoluteString]
                        UIApplication.shared.requestSceneSessionActivation(session, userActivity: userActivity, options: nil)
                    }
                }
        }
    }
}
