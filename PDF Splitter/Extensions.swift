//
//  SwiftUI+Extensions.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 9/13/22.
//

import Foundation
import SwiftUI

extension String {
    static var openPDFUserActivityType: String {
        (Bundle.main.bundleIdentifier ?? "") + ".openpdf"
    }
    
    static var openedPDFConfigurationName: String {
       "Opened PDF Configuration"
    }
}

private struct URLEnvironmentKey: EnvironmentKey {
    static let defaultValue: URL = URL(string: "www.apple.com")!
}

extension EnvironmentValues {
    var pdfUrl: URL {
        get { self[URLEnvironmentKey.self] }
        set { self[URLEnvironmentKey.self] = newValue }
    }
}
