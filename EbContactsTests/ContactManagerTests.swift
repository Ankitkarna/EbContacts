//
//  ContactManagerTests.swift
//  ContactImporterTests
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import XCTest
@testable import BaxtaContactFramework

class ContactManagerTests: XCTestCase {
    
    var contactManager: ContactManager!
    var contactStore: MockContactStore!
    var dataStack: MockCoreDataStack!
    var dbManager: DatabaseManager!
    
    private let mockContacts = MockContactStore.generateContacts(count: 5)
    
    override func setUp() {
        contactStore = MockContactStore(contacts: mockContacts)
        dataStack = MockCoreDataStack(isPersistent: true)
        dbManager = DatabaseManager(dataStack: dataStack)
        let contactImporter = SystemContactImporter(contactStore: contactStore, dbManager: dbManager)
        contactManager = ContactManager(contactImporter: contactImporter)
    }
    
    override func tearDown() {
        contactManager = nil
        dbManager = nil
        dataStack = nil
        contactStore = nil
    }
}
