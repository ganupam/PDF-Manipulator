//
//  Keychain.swift
//  PDF Manipulator
//
//  Created by Anupam Godbole on 10/3/22.
//

import Foundation

final class KeychainManager: NSObject {
    class func save(key: String, value: Data) {
        let query: [String : Any] = [kSecClass as String : kSecClassGenericPassword, kSecAttrAccount as String : key, kSecValueData as String : value, kSecAttrSynchronizable as String : kCFBooleanTrue!]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let attributesToUpdate : [String : Any] = [kSecValueData as String : value]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }

    class func get(key:String) -> Data? {
        var item : CFTypeRef?
        let getNameQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecMatchLimit as String : kSecMatchLimitOne,
                                           kSecAttrAccount as String: key,
                                           kSecReturnData as String: kCFBooleanTrue!,
                                           kSecAttrSynchronizable as String : kCFBooleanTrue!]

        if SecItemCopyMatching(getNameQuery as CFDictionary, &item) == errSecSuccess, let item = item as? Data {
            return item
        }
        return nil
    }
    
    class func delete(key: String) {
        let deleteNameQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                           kSecAttrAccount as String: key,
                                              kSecAttrSynchronizable as String : kCFBooleanTrue!]

        SecItemDelete(deleteNameQuery as CFDictionary)
    }
}
