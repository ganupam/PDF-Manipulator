//
//  RecentlyOpenFilesManager.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/16/22.
//

import UIKit
import Foundation

final class RecentlyOpenFilesManager: NSObject, ObservableObject {
    private static let filename = "RecentlyOpenFiles.data"
    
    static let sharedInstance = RecentlyOpenFilesManager()
    @Published private(set) var urls: [URL]
    
    private override init() {
        self.urls = []

        if let fileData = try? Data(contentsOf: .documentsFolder.appendingPathComponent(Self.filename)) {
            self.urls = (try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSURL.self, from: fileData) as? [URL]) ?? []
        }
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    func addURL(_ url: URL) {
        self.removeURL(url)
        
        self.urls.insert(url, at: 0)
    }
    
    @inline(__always) func removeURL(_ url: URL) {
        self.urls.removeAll {
            $0 == url
        }
    }
    
    @objc func save() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self.urls, requiringSecureCoding: false)
            try data.write(to: .documentsFolder.appendingPathComponent(Self.filename))
        }
        catch {
            print("Error saving recently opened files: \(error.localizedDescription)")
        }
    }
}
