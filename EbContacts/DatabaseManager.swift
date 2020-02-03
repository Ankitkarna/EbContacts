//
//  DatabaseManager.swift
//  ContactImporter
//
//  Created by Ankit Karna on 12/18/19.
//  Copyright © 2019 Ankit Karna. All rights reserved.
//

import Foundation
import CoreData

final public class DatabaseManager {
    public let dataStack: DataStackConfirmable
    
    public init(dataStack: DataStackConfirmable) {
        self.dataStack = dataStack
    }
    
    public func fetchObjects<T: Managed>(predicate: NSPredicate? = nil, relationshipKeyPathsForPrefetching: [String] = [], sortDescriptors: [NSSortDescriptor] = [], in context: NSManagedObjectContext? = nil) -> [T] {
        let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: T.entityName)
        if let predicate = predicate {
            request.predicate = predicate
        }
        if !sortDescriptors.isEmpty {
            request.sortDescriptors = sortDescriptors
        } else {
            request.sortDescriptors = T.defaultSortDescriptors
        }
        request.relationshipKeyPathsForPrefetching = relationshipKeyPathsForPrefetching
        let dbContext = context ?? dataStack.viewContext
        if let objects = try? dbContext.fetch(request) {
            return objects
        } else {
            return []
        }
    }
    
    public func updateObjects<T: Managed>(type: T.Type, predicate: NSPredicate? = nil, propertiesToUpdate: [AnyHashable: Any]) {
        let context = dataStack.savingContext
        let request = NSBatchUpdateRequest(entityName: T.entityName)
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = NSBatchUpdateRequestResultType.updatedObjectIDsResultType
        guard let result = try? context.execute(request) as? NSBatchUpdateResult,
            let objectIDArray = result.result as? [NSManagedObjectID] else { return }
        let changes = [NSUpdatedObjectsKey: objectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable: Any], into: [dataStack.savingContext])
    }
    
    public func deleteObjects<T: Managed>(type: T.Type, predicate: NSPredicate? = nil, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: T.entityName)
        fetchRequest.predicate = predicate
        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
        guard let result = try? context.execute(request) as? NSBatchDeleteResult,
            let objectIDArray = result.result as? [NSManagedObjectID] else { return }
        let changes = [NSDeletedObjectsKey: objectIDArray]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable: Any], into: [dataStack.savingContext])
    }
}
