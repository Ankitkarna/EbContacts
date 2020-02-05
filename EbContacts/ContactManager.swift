//
//  ContactManager.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/4/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation
import Contacts

open class ContactManager: NSObject {
    
    public let contactImporter: SystemContactImporter
    private let queue = OperationQueue()
    ///whether to allow framework to automatically delete removed system contacts or just set deleted flag on removed contacts
    public var deleteRemovedContacts = false
    
    public var onSystemContactChange: (() -> Void)?
    
    public init(contactImporter: SystemContactImporter = SystemContactImporter()) {
        self.contactImporter = contactImporter
        contactImporter.deleteRemovedContacts = deleteRemovedContacts
        super.init()
        observeNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .CNContactStoreDidChange, object: nil)
    }
    
    private func observeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleContactsChanged), name: .CNContactStoreDidChange, object: nil)
    }
    
    @objc private func handleContactsChanged() {
        onSystemContactChange?()
    }
    
    public func fetchSystemContactsAndInsertToDB(completion: @escaping (Error?) -> Void) {
        let fetchOperationQueable = ContactFetchOperation(contactImporter: contactImporter)
        let fetchOperation = BaxtaOperation(queueable: fetchOperationQueable)
        
        let completionHandler = {
            completion(fetchOperation.error)
        }
        fetchOperation.completionBlock = { 
            Helper.performOnMainThread(completionHandler)
        }
        
        queue.addOperation(fetchOperation)
    }
}
