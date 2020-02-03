//
//  ContactFetchOperation.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/22/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation
import Contacts

class ContactFetchOperation: OperationQueueable {
    var onFinish: ((Error?) -> Void)?
    private let contactImporter: SystemContactImporter
    
    init(contactImporter: SystemContactImporter) {
        self.contactImporter = contactImporter
    }
    
    func start() {
        let finishHandler: (Error?) -> Void = { (error) in
            DispatchQueue.main.async {
                self.onFinish?(error)
            }
        }
        
        fetchSystemContactsAndInsertToDB { (error) in
            finishHandler(error)
        }
    }
    
    private func updateSystemContactsToDB(systemContacts: [CNContact]) {
        let systemContactIds = systemContacts.map { $0.identifier }
        contactImporter.deleteDBContacts(except: systemContactIds, type: .phoneBook)
        contactImporter.insertSystemContactsToDB(systemContacts: systemContacts)
    }
    
    private func fetchSystemContactsAndInsertToDB(completion: @escaping (Error?) -> Void) {
       contactImporter.fetchContacts { [weak self] (result) in
           switch result {
           case .success(let contacts):
            self?.updateSystemContactsToDB(systemContacts: contacts)
            completion(nil)
           case .failure(let error):
               completion(error)
           }
       }
    }
}
