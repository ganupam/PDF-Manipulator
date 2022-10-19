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
    static let URLAddedNotification = NSNotification.Name("URLAddedNotification")
    static let urlUserInfoKey = "url"
    
    static let sharedInstance = RecentlyOpenFilesManager()
    @Published private(set) var urls: [URL]
    
    private override init() {
        self.urls = []

        if let fileData = try? Data(contentsOf: .documentsFolder.appendingPathComponent(Self.filename)) {
            let urlsData = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(fileData) as? [Data]) ?? []
            self.urls = urlsData.compactMap {
                var isBookmarkStale = false
                return try? URL(resolvingBookmarkData: $0, bookmarkDataIsStale: &isBookmarkStale)
            }
        }
        
        super.init()
        
        self.removeNonExistentFiles()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            self?.removeNonExistentFiles()
        }
    }
    
    private func removeNonExistentFiles() {
        self.urls.removeAll { url in
            !FileManager.default.fileExists(atPath: url.path)
        }
    }
    
    func addURL(_ url: URL) {
        self.urls.removeAll {
            $0 == url
        }

        self.urls.insert(url, at: 0)

        // No more than 25 items
        for i in stride(from: self.urls.count - 1, through: 25, by: -1) {
            self.urls.remove(at: i)
        }
        
        NotificationCenter.default.post(name: Self.URLAddedNotification, object: nil, userInfo: [Self.urlUserInfoKey : url])
        
        self.save()
    }
    
    @inline(__always) func removeURL(_ url: URL) {
        self.urls.removeAll {
            $0 == url
        }
        
        self.save()
    }
    
    private func save() {
        do {
            let urlsData = self.urls.compactMap {
                try? $0.bookmarkData(options: .minimalBookmark)
            }
            let data = try NSKeyedArchiver.archivedData(withRootObject: urlsData, requiringSecureCoding: false)
            try data.write(to: .documentsFolder.appendingPathComponent(Self.filename))
        }
        catch {
            print("Error saving recently opened files: \(error.localizedDescription)")
        }
    }
}
