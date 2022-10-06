//
//  RecentlyOpenedPDFsViewController.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/4/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class RecentlyOpenedPDFsViewController: UIHostingController<RecentlyOpenedPDFsViewController.RecentlyOpenedPDFsView> {
    let scene: UIWindowScene
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    
    init(scene: UIWindowScene) {
        self.scene = scene
        
        super.init(rootView: RecentlyOpenedPDFsView())        
//        if let documentFolder = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
//            print("Documents folder: ", documentFolder)
//        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.rootView = RecentlyOpenedPDFsView(scene: self.scene)
    }
    
    struct RecentlyOpenedPDFsView: View {
        private(set) var scene: UIWindowScene? = nil
        
        @State private var showingFilePicker = false

        var body: some View {
            Text(verbatim: "Main View")
                .navigationTitle("PDF Manipulator")
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
                        
                        guard url.startAccessingSecurityScopedResource(), let bookmarkData = try? url.bookmarkData(options: .minimalBookmark) else {
                            UIAlertController.show(message: NSLocalizedString("unableToOpen", comment: ""), scene: scene!)
                            return
                        }
                        
                        let session = UIApplication.shared.openSessions.first {
                            $0.userInfo?[.urlBookmarkDataKey] as? Data == bookmarkData
                        }
                        
                        let activationOptions = UIWindowScene.ActivationRequestOptions()
                        activationOptions.requestingScene = self.scene

                        let userActivity: NSUserActivity?
                        if session == nil {
                            userActivity = NSUserActivity(activityType: .openPDFUserActivityType)
                            userActivity?.userInfo = [String.urlBookmarkDataKey : bookmarkData]
                        } else {
                            userActivity = nil
                        }
                        UIApplication.shared.requestSceneSessionActivation(session, userActivity: userActivity, options: activationOptions)
                    }
                }
        }
    }
}
