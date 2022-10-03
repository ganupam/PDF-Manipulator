//
//  SwiftUI+Extensions.swift
//  PDF Splitter
//
//  Created by Anupam Godbole on 9/13/22.
//

import Foundation
import SwiftUI

private struct BindingBoolEnvironmentKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

private struct BindingOptionalURLEnvironmentKey: EnvironmentKey {
    static let defaultValue: Binding<URL?> = .constant(nil)
}

extension EnvironmentValues {
    var hasOpenedPDF: Binding<Bool> {
        get { self[BindingBoolEnvironmentKey.self] }
        set { self[BindingBoolEnvironmentKey.self] = newValue }
    }
    
    var pdfUrl: Binding<URL?> {
        get { self[BindingOptionalURLEnvironmentKey.self] }
        set { self[BindingOptionalURLEnvironmentKey.self] = newValue }
    }
}
