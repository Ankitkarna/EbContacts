//
//  TestCoreDataStack.swift
//  ContactImporterTests
//
//  Created by Ankit Karna on 12/5/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation
import CoreData

public class MockCoreDataStack: DataStackConfirmable {
    public let persistentContainer: NSPersistentContainer
    public lazy var viewContext: NSManagedObjectContext = {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    public lazy var savingContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()
    
    let isPersistent: Bool
    
    public init(isPersistent: Bool = false) {
        self.isPersistent = isPersistent
        let container = CoreDataStack.getPersistentContainer()
        if isPersistent {
            container.persistentStoreDescriptions[0].url = URL(fileURLWithPath: "/dev/null")
        } else {
            let persistentStoreDescription = NSPersistentStoreDescription()
            persistentStoreDescription.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [persistentStoreDescription]
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError(
                    "Unresolved error \(error), \(error.userInfo)")
            } }
        
        self.persistentContainer = container
    }
    
    public func saveContext() {
        guard savingContext.hasChanges else { return }
        savingContext.performAndWait {
            do {
                try savingContext.save()
            } catch {
                savingContext.rollback()
            }
            
        }
    }
}
