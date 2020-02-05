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
    @NSManaged public var countryCode: String
    @NSManaged public var phoneNumber: String
    @NSManaged public var fullPhoneNumber: String
    @NSManaged public var email: String?
    
    @NSManaged public var contact: BaxtaContact?
    @NSManaged public var fbId: String?
    @NSManaged public var user: BaxtaAppUser?
    @NSManaged public var serverId: String?
    
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
    
    private static var defaultCountryCode: String = getDefaultCountryCode()
    
    static func isDbPhoneNumbersEqualToSystemPhoneNumbers(dbPhoneNumbers: Set<BaxtaPhoneNumber>, systemPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> Bool {
        guard dbPhoneNumbers.count == systemPhoneNumbers.count else { return false }
        let systemPhoneValues = systemPhoneNumbers.map { $0.value.stringValue }
        let dbPhoneValues = dbPhoneNumbers.map { $0.fullPhoneNumber }
        return Set(systemPhoneValues) == Set(dbPhoneValues)
    }
    
    static func getDbPhoneNumbers(dbContact: BaxtaContact, systemPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> Set<BaxtaPhoneNumber> {
        let phoneValues = systemPhoneNumbers.map { $0.value.stringValue }
        let phonePredicate = NSPredicate(format: "%K in %@", #keyPath(BaxtaPhoneNumber.fullPhoneNumber), phoneValues)
        
        let context = dbContact.managedObjectContext!
        
        let unchangedContacts = BaxtaPhoneNumber.fetch(in: context) { (request) in
            request.predicate = phonePredicate
        }
        
        let unchangedContactsPhoneValues = unchangedContacts.map { $0.fullPhoneNumber }
        let changedContactsPhoneValues = Array(Set(phoneValues).subtracting(Set(unchangedContactsPhoneValues)))
    
        //delete all the changed contacts at last
        defer {
            let dbManager = DatabaseManager(dataStack: CoreDataStack.shared)
            let predicate = NSPredicate(format: "%K == %@ and not (%K in %@)", #keyPath(BaxtaPhoneNumber.contact.contactId), dbContact.contactId, #keyPath(BaxtaPhoneNumber.fullPhoneNumber), unchangedContactsPhoneValues)
            dbManager.deleteObjects(type: BaxtaPhoneNumber.self, predicate: predicate, context: context)
        }
        
        let changedContacts: [BaxtaPhoneNumber] = changedContactsPhoneValues.map { (phone) in
            let contact: BaxtaPhoneNumber = context.insertObject()
            contact.insertOrUpdate(contact: dbContact, systemPhoneNumber: phone)
            return contact
        }
        
        return Set(unchangedContacts + changedContacts)
    }
    
    private static func getMaterializedPhoneOrInsert(dbContact: BaxtaContact, systemPhone: String) -> BaxtaPhoneNumber {
        let context = dbContact.managedObjectContext!
        let predicate = NSPredicate(format: "%K == %@", #keyPath(BaxtaPhoneNumber.fullPhoneNumber), systemPhone)
        let dbPhoneNumber: BaxtaPhoneNumber
        if let phone: BaxtaPhoneNumber = findOrFetch(in: context, matching: predicate) {
            dbPhoneNumber = phone
        } else {
            dbPhoneNumber = context.insertObject()
        }
        dbPhoneNumber.insertOrUpdate(contact: dbContact, systemPhoneNumber: systemPhone)
        return dbPhoneNumber
    }
    
    static func insertPhoneNumbers(dbContact: BaxtaContact, systemPhoneNumbers: [CNLabeledValue<CNPhoneNumber>]) -> Set<BaxtaPhoneNumber> {
        var dbPhoneNumbers: [BaxtaPhoneNumber] = []
        let context = dbContact.managedObjectContext!
        for phone in systemPhoneNumbers {
            let phoneValue = phone.value.stringValue
            let dbPhone: BaxtaPhoneNumber = context.insertObject()
            dbPhone.insertOrUpdate(contact: dbContact, systemPhoneNumber: phoneValue)
            dbPhoneNumbers.append(dbPhone)
        }
       
        return Set(dbPhoneNumbers)
    }
    
    private func insertOrUpdate(contact: BaxtaContact, systemPhoneNumber: String) {
        fullPhoneNumber = systemPhoneNumber
        (countryCode, phoneNumber) = BaxtaPhoneNumber.separateCodeAndPhoneNumber(text: systemPhoneNumber)
        contactType = .phoneBook
        fullName = contact.fullName
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
        return [NSSortDescriptor(keyPath: \BaxtaPhoneNumber.fullName, ascending: true),
                NSSortDescriptor(keyPath: \BaxtaPhoneNumber.fullPhoneNumber, ascending: true)]
    }
}

extension BaxtaPhoneNumber {
    static func separateCodeAndPhoneNumber(text: String) -> (String, String) {
        let regex = "\\+[0-9]{1,3}"
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
                
                let codeStringValue = code.components(separatedBy: decimalCharacterSet).joined()
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
