//
//  BaxtaEmail.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import CoreData
import Contacts

final public class BaxtaEmail: NSManagedObject, Encodable {
    @NSManaged public var emailAddress: String
    @NSManaged public var contact: BaxtaContact?
    
    @NSManaged public var phoneId: String?
    
    ///the raw value for contact type (enum ContactType) to store in db.
    ///it will not be accessible to other users.
    ///to get this value use, @contactType
    @NSManaged private(set) public var type: Int32
    
    ///the accessible value for the types of contact stored in db
    public var contactType: AppContactType {
        get {
            return AppContactType(rawValue: type) ?? .phoneBook
        }
        set {
            type = newValue.rawValue
        }
    }
    
    @NSManaged private(set) public var state: Int32
    public var phoneState: DBContactState {
        get {
            return DBContactState(rawValue: state) ?? .deletedOrNotAvailable
        }
        set {
            state = newValue.rawValue
        }
    }
    
    static func isDBEmailsEqualToSystemEmails(dbEmails: Set<BaxtaEmail>, systemEmails: [CNLabeledValue<NSString>]) -> Bool {
        guard dbEmails.count == systemEmails.count else { return false }
        let systemEmailValues = systemEmails.map { String($0.value) }
        let dbEmailValues = dbEmails.map { $0.emailAddress }
        return Set(systemEmailValues) == Set(dbEmailValues)
    }
    
    static func getEmail(from email: String,
                         context: NSManagedObjectContext) -> BaxtaEmail {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(emailAddress), email)
        let entity: BaxtaEmail = context.fetchOrInsert(predicate: predicate)
        entity.emailAddress = email
        return entity
    }
    
    static func getDBEmails(dbContact: BaxtaContact, systemEmails: [CNLabeledValue<NSString>]) -> Set<BaxtaEmail> {
        let emailIdentifiers = systemEmails.map { $0.identifier }
        let emailPredicate = NSPredicate(format: "%K in %@", #keyPath(BaxtaEmail.phoneId), emailIdentifiers)
        let contactPredicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaEmail.contact.contactId), dbContact.contactId)
        
        let context = dbContact.managedObjectContext!
        
        let totalPhoneContacts = BaxtaEmail.fetch(in: context) { (request) in
            request.predicate = contactPredicate
        }
        
        let existingContacts = BaxtaEmail.fetch(in: context) { (request) in
            request.predicate = emailPredicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \BaxtaEmail.phoneId, ascending: true)]
        }
        let existingContactIds = existingContacts.compactMap { $0.phoneId }
        var existingContactPhones = systemEmails.filter { existingContactIds.contains($0.identifier) }
        existingContactPhones.sort(by: { $0.identifier < $1.identifier })
        for (contact, systemContact) in zip(existingContacts, existingContactPhones) {
            precondition(contact.phoneId == systemContact.identifier)
            if contact.emailAddress == String(systemContact.value) {
                contact.phoneState = .existing
            } else {
                contact.phoneState = .updated
                contact.insertOrUpdate(contact: contact.contact!, systemEmail: systemContact)
            }
        }
        
        let deletedContacts = Set(totalPhoneContacts).subtracting(Set(existingContacts))
        deletedContacts.forEach { $0.phoneState = .deletedOrNotAvailable }
        
        
        let newContacts = Array(Set(systemEmails).subtracting(Set(existingContactPhones)))
        
        let changedContacts: [BaxtaEmail] = newContacts.map { (email) in
            let contact: BaxtaEmail = context.insertObject()
            contact.phoneState = .inserted
            contact.insertOrUpdate(contact: dbContact, systemEmail: email)
            return contact
        }
        
        return Set(existingContacts + changedContacts + deletedContacts)
    }
    
    private static func getMaterializedEmailOrInsert(dbContact: BaxtaContact, systemEmail: CNLabeledValue<NSString>) -> BaxtaEmail {
        let context = dbContact.managedObjectContext!
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaEmail.emailAddress), systemEmail)
        let dbEmail: BaxtaEmail
        if let email: BaxtaEmail = findOrFetch(in: context, matching: predicate) {
            dbEmail = email
            dbEmail.phoneState = .updated
        } else {
            dbEmail = context.insertObject()
            dbEmail.phoneState = .inserted
        }
        dbEmail.insertOrUpdate(contact: dbContact, systemEmail: systemEmail)
        return dbEmail
    }
    
    static func insertEmails(dbContact: BaxtaContact, systemEmails: [CNLabeledValue<NSString>]) -> Set<BaxtaEmail> {
        var dbEmails: [BaxtaEmail] = []
        let context = dbContact.managedObjectContext!
        for email in systemEmails {
            let dbEmail: BaxtaEmail = context.insertObject()
            dbEmail.phoneState = .inserted
            dbEmail.insertOrUpdate(contact: dbContact, systemEmail: email)
            dbEmails.append(dbEmail)
        }
       
        return Set(dbEmails)
    }
    
    private func insertOrUpdate(contact: BaxtaContact, systemEmail: CNLabeledValue<NSString>) {
        phoneId = systemEmail.identifier
        emailAddress = String(systemEmail.value)
        contactType = .phoneBook
    }
}

extension BaxtaEmail: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(keyPath: \BaxtaEmail.emailAddress, ascending: true)]
    }
}
