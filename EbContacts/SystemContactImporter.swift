//
//  ContactManager.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/3/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation
import Contacts
import ContactsUI
import CoreData

public enum ContactError: Error {
    case accessDenied
    case internalError
    case dbInsertionFailed
}

extension ContactError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .accessDenied: return "Please provide access."
        case .internalError: return "Internal Fetch Error."
        case .dbInsertionFailed: return "Failed to insert in db"
        }
    }
}

public class SystemContactImporter: NSObject {
    
    public typealias ContactFetchCompletionHandler = (Result<[CNContact], Error>) -> Void
    
    private let contactStore: ContactStore
    let context: NSManagedObjectContext
    public let dbManager: DatabaseManager
    
    private let allowedContactKeys: [CNKeyDescriptor] = [
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactViewController.descriptorForRequiredKeys()
    ]
    
    var deleteRemovedContacts: Bool = false
    var authorizationStatus: CNAuthorizationStatus { contactStore.status }
    
    public init(contactStore: ContactStore = CNContactStore(),
         dbManager: DatabaseManager = DatabaseManager(dataStack: CoreDataStack.shared)) {
        self.contactStore = contactStore
        self.dbManager = dbManager
        self.context = dbManager.dataStack.savingContext
        super.init()
    }
    
    public func fetchContacts(completion: @escaping ContactFetchCompletionHandler) {
        switch authorizationStatus {
        case .authorized:
            let contacts = self.fetchSystemContacts()
            completion(.success(contacts))
        case .notDetermined:
            self.requestAccessAndFetchContacts(completion: completion)
        default:
            completion(.failure(ContactError.accessDenied))
        }
    }
    
    @discardableResult
    func insertSystemContactsToDB(systemContacts: [CNContact]) -> [BaxtaContact] {
        guard !systemContacts.isEmpty else { return [] }
        var dbContacts: [BaxtaContact] = []
        context.performChangesAndWait { [weak self, context] in
            guard let self = self else { return }
            dbContacts = self.performInsertionToDB(contacts: systemContacts, in: context)
        }
        return dbContacts
    }
    
    func deleteSystemContactsFromDb(excluding contactIds: [String]) {
        let operation: () -> Void = {
            if self.deleteRemovedContacts {
                self.deleteDBContacts(excluding: contactIds, type: .phoneBook)
                self.removeDeletedPhoneNumbers()
            } else {
                self.setFlagsForDeletedDbContacts(excluding: contactIds)
            }
        }
        context.performChangesAndWait(block: operation)
    }
    
    private func fetchSystemContacts() -> [CNContact] {
        var systemContacts = [CNContact]()
        let contactFetchRequest = CNContactFetchRequest(keysToFetch: self.allowedContactKeys)
        contactFetchRequest.sortOrder = .userDefault
        try? self.contactStore.enumerateContacts(with: contactFetchRequest) { (contact, _) -> Void in
            systemContacts.append(contact)
        }
       
        return systemContacts
    }
    
    private func requestAccessAndFetchContacts(completion: @escaping ContactFetchCompletionHandler) {
        self.contactStore.requestAccess(for: .contacts) { [weak self] (isGranted, error) in
            guard let self = self else { return }
            if isGranted {
                let contacts = self.fetchSystemContacts()
                completion(.success(contacts))
            } else if let error = error {
                completion(.failure(error))
            }
        }
    }
    
    private func performInsertionToDB(contacts: [CNContact], in context: NSManagedObjectContext) -> [BaxtaContact] {
        let contactIds = contacts.map { $0.identifier }
        let predicate = NSPredicate(format: "(%K in %@)",
                                    #keyPath(BaxtaContact.contactId), contactIds)
        let relationshipPrefetchingKeyPaths = [#keyPath(BaxtaContact.phoneNumbers), #keyPath(BaxtaContact.emails)]
        let sortDescriptors = [NSSortDescriptor(keyPath: \BaxtaContact.contactId, ascending: true)]
        
        let existingDbContacts: [BaxtaContact] = dbManager.fetchObjects(predicate: predicate, relationshipKeyPathsForPrefetching: relationshipPrefetchingKeyPaths, sortDescriptors: sortDescriptors, in: context)
        
        if existingDbContacts.isEmpty {
            let newDBContacts: [BaxtaContact] = contacts.map { BaxtaContact.insertSystemContact($0, context: context)
            }
            return newDBContacts
        } else {
           return handleOldContacts(contacts, existingDbContacts: existingDbContacts)
        }
    }
    
    private func handleOldContacts(_ contacts: [CNContact], existingDbContacts: [BaxtaContact]) -> [BaxtaContact] {
        let dbContactIds = existingDbContacts.map { $0.contactId }
        let existingPredicate = NSPredicate(format: "%K in %@", #keyPath(CNContact.identifier), dbContactIds)

        var existingContacts = (contacts as NSArray).filtered(using: existingPredicate) as! [CNContact]
        let newContacts = Array(Set(contacts).subtracting(Set(existingContacts)))
        
        let newDbContacts: [BaxtaContact] = newContacts.map { BaxtaContact.insertSystemContact($0, context: context)
        }
        existingContacts.sort(by: { $0.identifier < $1.identifier })
        
        var existingContactIds: [String] = []
        for (contact, dbContact) in zip(existingContacts, existingDbContacts) {
            precondition(contact.identifier == dbContact.contactId)
            
            if dbContact.isEqualToSystemContact(contact) {
                existingContactIds.append(dbContact.contactId)
            } else {
                dbContact.updateDBContact(systemContact: contact)
            }
        }
        
        setFlagsForExistingDbContacts(contactIds: existingContactIds)
        return newDbContacts + existingDbContacts
    }
}

extension SystemContactImporter {
    private func setFlagsForExistingDbContacts(contactIds: [String]) {
        let predicate = NSPredicate(format: "%K in %@", #keyPath(BaxtaContact.contactId), contactIds)
        dbManager.updateObjects(type: BaxtaContact.self, predicate: predicate, propertiesToUpdate: [#keyPath(BaxtaContact.state): DBContactState.existing.rawValue], context: context)
    }
    
    private func setFlagsForDeletedDbContacts(excluding contactIds: [String]) {
        guard !contactIds.isEmpty else { return }
        let predicate = NSPredicate(format: "not %K in %@", #keyPath(BaxtaContact.contactId), contactIds)
        dbManager.updateObjects(type: BaxtaContact.self, predicate: predicate, propertiesToUpdate: [#keyPath(BaxtaContact.state): DBContactState.deletedOrNotAvailable.rawValue], context: context)
    }
    
    private func deleteDBContacts(excluding contactIds: [String], type: AppContactType) {
        let predicate: NSPredicate
        if !contactIds.isEmpty {
            predicate = NSPredicate(format: "not (%K in %@) and (any %K == %d)",
                                    #keyPath(BaxtaContact.contactId), contactIds, #keyPath(BaxtaContact.phoneNumbers.type), type.rawValue)
        } else {
            predicate = NSPredicate(format: "%K == %d", #keyPath(BaxtaContact.phoneNumbers.type), type.rawValue)
        }
        dbManager.deleteObjects(type: BaxtaContact.self, predicate: predicate, context: context)
    }
    
    private func removeDeletedPhoneNumbers() {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaPhoneNumber.state), DBContactState.deletedOrNotAvailable.rawValue)
        dbManager.deleteObjects(type: BaxtaPhoneNumber.self, predicate: predicate, context: context)
    }
}
