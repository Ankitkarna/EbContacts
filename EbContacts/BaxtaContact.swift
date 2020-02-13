//
//  BaxtaContact.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import CoreData
import Contacts

public enum AppContactType: Int32 {
    case phoneBook
    case app
    case faceBook
}

public enum DBContactState: Int32 {
    case inserted, existing, updated, deletedOrNotAvailable
}

final public class BaxtaContact: NSManagedObject {
    @NSManaged public var contactId: String
    @NSManaged public var fullName: String
    @NSManaged public var profilePhotoData: Data?
    @NSManaged private(set) public var state: Int32
    
    @NSManaged public var isSyncedWithApi: Bool

    @NSManaged public var phoneNumbers: Set<BaxtaPhoneNumber>
    @NSManaged public var emails: Set<BaxtaEmail>
    
    public var contactState: DBContactState {
        get {
            return DBContactState(rawValue: state) ?? .deletedOrNotAvailable
        }
        set {
            state = newValue.rawValue
        }
    }
    
    func isEqualToSystemContact(_ contact: CNContact) -> Bool {
        return contact.identifier == contactId &&
            contact.fullName == fullName &&
            contact.thumbnailImageData == profilePhotoData &&
            BaxtaEmail.isDBEmailsEqualToSystemEmails(dbEmails: emails, systemEmails: contact.emailAddresses) &&
            BaxtaPhoneNumber.isDbPhoneNumbersEqualToSystemPhoneNumbers(dbPhoneNumbers: phoneNumbers, systemPhoneNumbers: contact.phoneNumbers)
    }
    
    static public func findContact(contactId: String, context: NSManagedObjectContext) -> BaxtaContact? {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaContact.contactId), contactId)
        return BaxtaContact.findOrFetch(in: context, matching: predicate)
    }
    
    static func insertSystemContact(_ systemContact: CNContact, context: NSManagedObjectContext) -> BaxtaContact {
        let dbContact: BaxtaContact = context.insertObject()
        dbContact.contactState = .inserted
        dbContact.updateOrInsert(systemContact: systemContact, state: .inserted)
        return dbContact
    }
    
    func updateDBContact(systemContact: CNContact) {
        contactState = .updated
        updateOrInsert(systemContact: systemContact, state: .updated)
    }
    
    private func updateOrInsert(systemContact: CNContact, state: DBContactState) {
        let context = managedObjectContext!
        contactId = systemContact.identifier
        fullName = systemContact.fullName
        
        if systemContact.isKeyAvailable(CNContactThumbnailImageDataKey) {
            profilePhotoData = systemContact.thumbnailImageData
        }
        
        if systemContact.isKeyAvailable(CNContactPhoneNumbersKey) {
            if state == .inserted {
                phoneNumbers = BaxtaPhoneNumber.insertPhoneNumbers(dbContact: self, systemPhoneNumbers: systemContact.phoneNumbers)
            } else {
                phoneNumbers = BaxtaPhoneNumber.getDbPhoneNumbers(dbContact: self, systemPhoneNumbers: systemContact.phoneNumbers)
            }
        }
        
        if systemContact.isKeyAvailable(CNContactEmailAddressesKey) {
            if state == .inserted {
                emails = BaxtaEmail.insertEmails(dbContact: self, systemEmails: systemContact.emailAddresses)
            } else {
                emails = BaxtaEmail.getDBEmails(dbContact: self, systemEmails: systemContact.emailAddresses)
            }
        }
    }
}

extension BaxtaContact: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(keyPath: \BaxtaContact.fullName, ascending: true)]
    }
}

extension CNContact {
    public var fullName: String {
        if let fullName = CNContactFormatter.string(from: self, style: .fullName) {
            return fullName
        } else {
            return givenName + " " + familyName
        }
    }
}
