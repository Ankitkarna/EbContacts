//
//  MockContactStore.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation
import Contacts
import ContactsUI

public protocol ContactStore: AnyObject {
    var status: CNAuthorizationStatus { get }
    
    func enumerateContacts(with fetchRequest: CNContactFetchRequest, usingBlock block: @escaping (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void) throws
    func requestAccess(for entityType: CNEntityType, completionHandler: @escaping (Bool, Error?) -> Void)
}

extension CNContactStore: ContactStore {
    public var status: CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
}

public class MockContactStore: ContactStore {
    public var status: CNAuthorizationStatus = .authorized
    public var authorizeOnRequest = false
    
    var contacts: [CNMutableContact]
    
    public init(contacts: [CNMutableContact]) {
        self.contacts = contacts
    }
    
    public func enumerateContacts(with fetchRequest: CNContactFetchRequest, usingBlock block: @escaping (CNContact, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        for contact in contacts {
            let unsafeBoolPointer = UnsafeMutablePointer<ObjCBool>.init(bitPattern: 1)!
            block(contact, unsafeBoolPointer)
        }
    }
    
    public func requestAccess(for entityType: CNEntityType, completionHandler: @escaping (Bool, Error?) -> Void) {
        let error = authorizeOnRequest ? nil : ContactError.accessDenied
        completionHandler(authorizeOnRequest, error)
    }
    
    public static func getContact(givenName: String, familyName: String, phoneNumbers: [String], emailAddresses: [String]) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        
        let phoneLabels: [CNLabeledValue<CNPhoneNumber>] = phoneNumbers.map { (phoneNumber) in
            let phoneValue = CNPhoneNumber(stringValue: phoneNumber)
            let phoneLabel = CNLabeledValue(label: CNLabelHome, value: phoneValue)
            return phoneLabel
        }
        contact.phoneNumbers = phoneLabels
        
        let emailLabels: [CNLabeledValue<NSString>] = emailAddresses.map { (emailAddress) in
            let emailLabel = CNLabeledValue(label: CNLabelHome, value: emailAddress as NSString)
            return emailLabel
        }
        contact.emailAddresses = emailLabels
        
        return contact
    }
    
    public static func generateRandomContact(number: Int) -> CNMutableContact {
        let contact = getContact(givenName: "ankit\(number)", familyName: "karna", phoneNumbers: ["984982406\(number)"], emailAddresses: ["ankit.karna\(number)@gmail.com"])
        return contact
    }
    
    public static func generateContacts(count: Int) -> [CNMutableContact] {
        let contacts = (0..<count).map(Self.generateRandomContact)
        return contacts
    }
}
