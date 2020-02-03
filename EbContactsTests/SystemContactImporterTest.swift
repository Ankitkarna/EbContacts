//
//  ContactManagerTest.swift
//  ContactImporterTests
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import XCTest
import Contacts
@testable import BaxtaContactFramework

class SystemContactImporterTest: XCTestCase {
    //mock values
    var contactImporter: SystemContactImporter!
    var contactStore: MockContactStore!
    var dataStack: MockCoreDataStack!
    var dbManager: DatabaseManager!
    
    private let mockContacts = MockContactStore.generateContacts(count: 5)

    override func setUp() {
        contactStore = MockContactStore(contacts: mockContacts)
        dataStack = MockCoreDataStack(isPersistent: true)
        dbManager = DatabaseManager(dataStack: dataStack)
        contactImporter = SystemContactImporter(contactStore: contactStore, dbManager: dbManager)
    }
    
    private func fetchContacts() -> ([CNContact], Error?) {
        let promise = expectation(description: "total number of counts")
        var fetchedContacts: [CNContact] = []
        var fetchError: Error?
        contactImporter.fetchContacts { (result) in
            switch result {
            case .success(let contacts):
                fetchedContacts = contacts
            case .failure(let error):
                fetchError = error
            }
            promise.fulfill()
        }
        wait(for: [promise], timeout: 2)
        return (fetchedContacts, fetchError)
    }
    
    func testFetchContactIsDenied() {
        contactStore.status = .denied
        let authorizationStatus = contactImporter.authorizationStatus
        XCTAssert(authorizationStatus == .denied)
    }
    
    func testFetchContactIfDenied() {
        contactStore.status = .denied
        let (_, fetchError) = fetchContacts()
        XCTAssertNotNil(fetchError)
    }
    
    func testFetchContactIfNotDetermined_giveAccessOnRequest() {
        contactStore.status = .notDetermined
        contactStore.authorizeOnRequest = true
        let (fetchedContacts, fetchError) = fetchContacts()
        XCTAssertNil(fetchError)
        XCTAssertEqual(fetchedContacts.count, mockContacts.count)
    }
    
    func testFetchContactIfNotDetermined_rejectAccessOnRequest() {
        contactStore.status = .notDetermined
        contactStore.authorizeOnRequest = false
        let (_, fetchError) = fetchContacts()
        XCTAssertNotNil(fetchError)
    }
    
    func testFetchContactIfAuthorized() {
        contactStore.status = .authorized
        let (fetchedContacts, fetchError) = fetchContacts()
        XCTAssertNil(fetchError)
        XCTAssertEqual(fetchedContacts.count, mockContacts.count)
    }
    
    func testInsertSystemContactToDB() {
        let contact = MockContactStore.generateRandomContact(number: 0)
        let dbContacts = contactImporter.insertSystemContactsToDB(systemContacts: [contact])
        XCTAssertEqual(dbContacts.count, 1)
        let dbContact = dbContacts.first!
        XCTAssert(dbContact.contactState == .inserted, "contact state is \(dbContact.contactState)")
    }
    
    func testUpdateSystemContactToDB() {
        let contact = MockContactStore.generateRandomContact(number: 0)
        _ = contactImporter.insertSystemContactsToDB(systemContacts: [contact])
        let updatedContacts = performUpdateSystemContacts(oldContacts: [contact])
        let updatedDbContacts = contactImporter.insertSystemContactsToDB(systemContacts: updatedContacts)
        XCTAssertEqual(updatedDbContacts.count, 1)
        let dbContact = updatedDbContacts.first!
        XCTAssert(dbContact.contactState == .updated, "contact state is \(dbContact.contactState)")
    }
    
    func testDeleteSystemContactFromDB() {
        guard dataStack.isPersistent else {
            //batch delete doesn't work for non persistent database store so we just return
            return
        }
        let context = dataStack.savingContext
        context.performChangesAndWait {
            self.dbManager.deleteObjects(type: BaxtaContact.self, context: context)
        }
        
        let contact1 = MockContactStore.generateRandomContact(number: 0)
        let contact2 = MockContactStore.generateRandomContact(number: 1)
        _ = contactImporter.insertSystemContactsToDB(systemContacts: [contact1, contact2])
        let initalContacts: [BaxtaContact] = dbManager.fetchObjects()
        XCTAssertEqual(initalContacts.count, 2)
        contactImporter.deleteDBContacts(except: [contact1.identifier], type: .phoneBook)
        let finalContacts: [BaxtaContact] = dbManager.fetchObjects()
        XCTAssertEqual(finalContacts.count, 1)
        let finalContact = finalContacts.first!
        XCTAssert(finalContact.contactId == contact1.identifier)
    }
    
    func testLargeContactsInsertUpdateToDb() {
        let totalCount = 2000
        let contacts = MockContactStore.generateContacts(count: totalCount)
        let existingContacts = Array(contacts[0..<500])
        let toUpdateContacts = Array(contacts[500..<600])
        let newContacts = Array(contacts[600..<totalCount])
        
        contactImporter.insertSystemContactsToDB(systemContacts: existingContacts + toUpdateContacts)
        let newDbContacts = contactImporter.insertSystemContactsToDB(systemContacts: newContacts)
        let existingDbContacts = contactImporter.insertSystemContactsToDB(systemContacts: existingContacts)
        let updatedContacts = performUpdateSystemContacts(oldContacts: toUpdateContacts)
        let updateDbContacts = contactImporter.insertSystemContactsToDB(systemContacts: updatedContacts)
        
        XCTAssert(newDbContacts.allSatisfy { $0.contactState == .inserted })
        XCTAssert(existingDbContacts.allSatisfy { $0.contactState == .existing })
        XCTAssert(updateDbContacts.allSatisfy { $0.contactState == .updated })
    }
    
    func testLargeExistingContactsToDb() {
        let totalCount = 5000
        let contacts = MockContactStore.generateContacts(count: totalCount)
        
        contactImporter.insertSystemContactsToDB(systemContacts: contacts)
        let existingDbContacts = contactImporter.insertSystemContactsToDB(systemContacts: contacts)
        
        XCTAssert(existingDbContacts.allSatisfy { $0.contactState == .existing })
    }
    
    func testDuplicatePhoneNumbers() {
        let duplicateContact = MockContactStore.getContact(givenName: "Ankit", familyName: "karna", phoneNumbers: ["+977 9849824063", "+977 9849824063"], emailAddresses: [])
        contactImporter.insertSystemContactsToDB(systemContacts: [duplicateContact])
        contactImporter.insertSystemContactsToDB(systemContacts: [duplicateContact])
        
        let totalContacts: [BaxtaContact] = dbManager.fetchObjects()
        XCTAssertEqual(totalContacts.count, 1)
        let totalPhoneNumbers: [BaxtaPhoneNumber] = dbManager.fetchObjects()
        XCTAssertEqual(totalPhoneNumbers.count, 1)
        let phoneNumber = totalPhoneNumbers.first!
        let contact = totalContacts.first!
        XCTAssertEqual(phoneNumber.contact, contact)
    }
    
    private func performUpdateSystemContacts(oldContacts: [CNMutableContact]) -> [CNMutableContact] {
        var count = 0
        var newContacts: [CNMutableContact] = []
        let email = CNLabeledValue(label: CNLabelHome, value: "ankit.karna@gmail.com" as NSString)
        let phoneNumberValue = CNPhoneNumber(stringValue: "984132332")
        let phoneNumber = CNLabeledValue(label: CNLabelHome, value: phoneNumberValue)
        
        for oldContact in oldContacts {
            let newContact = oldContact
            switch count {
            case 0: newContact.familyName = "ka"
            case 1:
                newContact.emailAddresses = [email]
            case 2:
                newContact.phoneNumbers = [phoneNumber]
            default: fatalError()
            }
            newContacts.append(newContact)
            count = (count + 1) % 3

        }
      
        return newContacts
    }

    override func tearDown() {
        contactStore = nil
        contactImporter = nil
        dbManager = nil
        dataStack = nil
    }
}
