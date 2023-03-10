//
//  Keychain.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/3/22.
//

import Foundation

final class KeychainManager: NSObject {
    class func save(key: String, value: Codable, shouldSyncToiCloud: Bool = false) {
        var query: [String : Any] = [kSecClass as String : kSecClassGenericPassword, kSecAttrAccount as String : key, kSecValueData as String : value]
        if shouldSyncToiCloud {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue!
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributesToUpdate : [String : Any] = [kSecValueData as String : value]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }

    class func get(key:String, wasSyncedToiCloud: Bool = false) -> Codable? {
        var item : CFTypeRef?
        var getNameQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecMatchLimit as String : kSecMatchLimitOne,
                                           kSecAttrAccount as String: key,
                                           kSecReturnData as String: kCFBooleanTrue!]

        if wasSyncedToiCloud {
            getNameQuery[kSecAttrSynchronizable as String] = kCFBooleanTrue!
        }
        
        let status = SecItemCopyMatching(getNameQuery as CFDictionary, &item)
        return status == errSecSuccess ? item as? Codable : nil
    }
    
    class func delete(key: String, wasSyncedToiCloud: Bool = false) {
        var deleteNameQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecAttrAccount as String: key]

        if wasSyncedToiCloud {
            deleteNameQuery[kSecAttrSynchronizable as String] = kCFBooleanTrue!
        }

        SecItemDelete(deleteNameQuery as CFDictionary)
    }
}
