//
//  BaxtaPhoneNumber.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import CoreData
import Contacts

final public class BaxtaPhoneNumber: NSManagedObject {
    @NSManaged public var countryCode: String?
    @NSManaged public var phoneNumber: String?
    @NSManaged public var fullPhoneNumber: String?
    @NSManaged public var email: String?
    
    @NSManaged public var contact: BaxtaContact?
    @NSManaged public var fbId: String?
    @NSManaged public var user: BaxtaAppUser?
    @NSManaged public var serverId: String?
    
    @NSManaged public var phoneId: String?
    
    ///only used to sort by name
    @NSManaged public var fullName: String?
    
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
    
    private static var defaultCountryCode: String = getDefaultCountryCode()
    
    static func isDbPhoneNumbersEqualToSystemPhoneNumbers(dbPhoneNumbers: Set<BaxtaPhoneNumber>, systemPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> Bool {
        guard dbPhoneNumbers.count == systemPhoneNumbers.count else { return false }
        let systemPhoneValues = systemPhoneNumbers.map { $0.value.stringValue }
        let dbPhoneValues = dbPhoneNumbers.compactMap { $0.fullPhoneNumber }
        return Set(systemPhoneValues) == Set(dbPhoneValues)
    }
    
    static func getDbPhoneNumbers(dbContact: BaxtaContact, systemPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> Set<BaxtaPhoneNumber> {
        let phoneIdentifiers = systemPhoneNumbers.map { $0.identifier }
        let phonePredicate = NSPredicate(format: "%K in %@", #keyPath(BaxtaPhoneNumber.phoneId), phoneIdentifiers)
        let contactPredicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaPhoneNumber.contact.contactId), dbContact.contactId)
        
        let context = dbContact.managedObjectContext!
        
        let totalPhoneContacts = BaxtaPhoneNumber.fetch(in: context) { (request) in
            request.predicate = contactPredicate
        }
        
        let existingContacts = BaxtaPhoneNumber.fetch(in: context) { (request) in
            request.predicate = phonePredicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \BaxtaPhoneNumber.phoneId, ascending: true)]
        }
        let existingContactIds = existingContacts.compactMap { $0.phoneId }
        var existingContactPhones = systemPhoneNumbers.filter { existingContactIds.contains($0.identifier) }
        existingContactPhones.sort(by: { $0.identifier < $1.identifier })
        for (contact, systemContact) in zip(existingContacts, existingContactPhones) {
            precondition(contact.phoneId == systemContact.identifier)
            if contact.fullPhoneNumber == systemContact.value.stringValue {
                contact.phoneState = .existing
            } else {
                contact.phoneState = .updated
                contact.insertOrUpdate(contact: contact.contact!, systemPhoneNumber: systemContact)
            }
        }
        
        let deletedContacts = Set(totalPhoneContacts).subtracting(Set(existingContacts))
        deletedContacts.forEach { $0.phoneState = .deletedOrNotAvailable }
        
        
        let newContacts = Array(Set(systemPhoneNumbers).subtracting(Set(existingContactPhones)))
        
        let changedContacts: [BaxtaPhoneNumber] = newContacts.map { (phone) in
            let contact: BaxtaPhoneNumber = context.insertObject()
            contact.phoneState = .inserted
            contact.insertOrUpdate(contact: dbContact, systemPhoneNumber: phone)
            return contact
        }
        
        return Set(existingContacts + changedContacts + deletedContacts)
    }
    
    private static func getMaterializedPhoneOrInsert(dbContact: BaxtaContact, systemPhone: CNLabeledValue<CNPhoneNumber>) -> BaxtaPhoneNumber {
        let context = dbContact.managedObjectContext!
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaPhoneNumber.fullPhoneNumber), systemPhone)
        let dbPhoneNumber: BaxtaPhoneNumber
        if let phone: BaxtaPhoneNumber = findOrFetch(in: context, matching: predicate) {
            dbPhoneNumber = phone
            dbPhoneNumber.phoneState = .updated
        } else {
            dbPhoneNumber = context.insertObject()
            dbPhoneNumber.phoneState = .inserted
        }
        dbPhoneNumber.insertOrUpdate(contact: dbContact, systemPhoneNumber: systemPhone)
        return dbPhoneNumber
    }
    
    static func insertPhoneNumbers(dbContact: BaxtaContact, systemPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> Set<BaxtaPhoneNumber> {
        var dbPhoneNumbers: [BaxtaPhoneNumber] = []
        let context = dbContact.managedObjectContext!
        for phone in systemPhoneNumbers {
            let dbPhone: BaxtaPhoneNumber = context.insertObject()
            dbPhone.phoneState = .inserted
            dbPhone.insertOrUpdate(contact: dbContact, systemPhoneNumber: phone)
            dbPhoneNumbers.append(dbPhone)
        }
       
        return Set(dbPhoneNumbers)
    }
    
    private func insertOrUpdate(contact: BaxtaContact, systemPhoneNumber: CNLabeledValue<CNPhoneNumber>) {
        phoneId = systemPhoneNumber.identifier
        fullPhoneNumber = systemPhoneNumber.value.stringValue
        (countryCode, phoneNumber) = BaxtaPhoneNumber.separateCodeAndPhoneNumber(text: systemPhoneNumber.value.stringValue)
        contactType = .phoneBook
        fullName = contact.fullName
        
        //remove appuser if linked to the phone
        user = nil
    }
    
    static public func findContact(userId: String, context: NSManagedObjectContext) -> BaxtaPhoneNumber? {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaPhoneNumber.user.userId), userId)
        return BaxtaPhoneNumber.findOrFetch(in: context, matching: predicate)
    }
    
    static public func findPhoneNumber(phone: String, context: NSManagedObjectContext) -> BaxtaPhoneNumber? {
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaPhoneNumber.phoneNumber), phone)
        return BaxtaPhoneNumber.findOrFetch(in: context, matching: predicate)
    }
}

extension BaxtaPhoneNumber {
    @objc public var firstLetter: String? {
        if let first = self.fullName?.first {
            return String(first)
        } else {
            return nil
        }
    }
}

extension BaxtaPhoneNumber: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: #keyPath(BaxtaPhoneNumber.fullName), ascending: true, selector: #selector(NSString.caseInsensitiveCompare)),
                NSSortDescriptor(keyPath: \BaxtaPhoneNumber.fullPhoneNumber, ascending: true)]
    }
}

extension BaxtaPhoneNumber {
    static func separateCodeAndPhoneNumber(text: String) -> (String, String) {
        let regex = "(\\+|00)[0-9]{1,3}"
        let decimalCharacterSet = CharacterSet.decimalDigits.inverted
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            if let codeRange = results.first?.range {
                let start = text.index(text.startIndex, offsetBy: codeRange.location)
                let end = text.index(start, offsetBy: codeRange.length)
                let code = String(text[start..<end])
                let phone = String(text[end...])
                
                var codeStringValue = code.components(separatedBy: decimalCharacterSet).joined()
                if codeStringValue.hasPrefix("00") {
                    codeStringValue.removeFirst(2)
                }
                let phoneValue = phone.components(separatedBy: decimalCharacterSet).joined()
                return ("+" + codeStringValue, phoneValue) //"+" is added to make it consistent with api
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
        }
        let phoneValue = text.components(separatedBy: decimalCharacterSet).joined()
        return (defaultCountryCode, phoneValue)
    }
    
    static func getDefaultCountryCode() -> String {
        let defaultCountryCode = "+61"
        guard let countryCode = Locale.current.regionCode else { return defaultCountryCode }
       
        let resourceBundle = Bundle(for: self)
        guard let path = resourceBundle.path(forResource: "CallingCodes", ofType: "plist") else { return defaultCountryCode }
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            let decoder = PropertyListDecoder()
            let countries = try decoder.decode([CountryInfo].self, from: data)
            if let country = countries.first(where: {$0.countryCode == countryCode}) {
                return country.phoneCode
            }
        } catch {
            print(error)
        }
        
        return defaultCountryCode
    }
}
