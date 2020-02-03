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
    @NSManaged public var contact: BaxtaContact
    
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
        let emailValues = systemEmails.map { String($0.value) }
        let predicate = NSPredicate(format: "%K in %@", #keyPath(BaxtaEmail.emailAddress), emailValues)
        let context = dbContact.managedObjectContext!
        let oldContacts = BaxtaEmail.fetch(in: context) { (request) in
            request.predicate = predicate
        }
        let newPhoneNumbers = emailValues.filter { (email) in !oldContacts.contains(where: { $0.emailAddress == email })}
        let newContacts: [BaxtaEmail] = newPhoneNumbers.map { (email) in
            let contact: BaxtaEmail = context.insertObject()
            contact.insertOrUpdate(systemEmail: email)
            return contact
        }
        return Set(oldContacts + newContacts)
    }
    
    private static func getMaterializedEmailOrInsert(dbContact: BaxtaContact, systemEmail: String) -> BaxtaEmail {
        let context = dbContact.managedObjectContext!
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaEmail.emailAddress), systemEmail)
        let dbEmail: BaxtaEmail
        if let email: BaxtaEmail = findOrFetch(in: context, matching: predicate) {
            dbEmail = email
        } else {
            dbEmail = context.insertObject()
        }
        dbEmail.insertOrUpdate(systemEmail: systemEmail)
        return dbEmail
    }
    
    static func insertEmails(systemEmails: [CNLabeledValue<NSString>], context: NSManagedObjectContext) -> Set<BaxtaEmail> {
        var dbEmails: [BaxtaEmail] = []
        for email in systemEmails {
            let emailValue = String(email.value)
            let dbEmail: BaxtaEmail = context.insertObject()
            dbEmail.insertOrUpdate(systemEmail: emailValue)
            dbEmails.append(dbEmail)
        }
       
        return Set(dbEmails)
    }
    
    private func insertOrUpdate(systemEmail: String) {
        emailAddress = systemEmail
    }
}

extension BaxtaEmail: Managed {}
