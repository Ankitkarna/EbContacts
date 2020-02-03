//
//  Extensions.swift
//  Moody
//
//  Created by Florian on 07/05/15.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import CoreData

public extension NSManagedObjectContext {
    func fetchOrInsert<A: NSManagedObject>(predicate: NSPredicate) -> A where A: Managed {
        guard let object = A.findOrFetch(in: self, matching: predicate) else {
           return insertObject()
        }
        return object
    }

    func insertObject<A: NSManagedObject>() -> A where A: Managed {
        guard let obj = NSEntityDescription.insertNewObject(forEntityName: A.entityName, into: self) as? A else { fatalError("Wrong object type") }
        return obj
    }

    @discardableResult
    func saveOrRollback() -> Bool {
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            rollback()
            return false
        }
    }

    func performChanges(block: @escaping () -> Void = {}) {
        perform {
            block()
            self.saveOrRollback()
        }
    }

    func performChangesAndWait(block: @escaping () -> Void = {}) {
        performAndWait {
            block()
            self.saveOrRollback()
        }
    }
}
