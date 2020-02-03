//
//  CoreDataStack.swift
//  EbDemoChat
//
//  Created by Ankit Karna on 12/20/18.
//  Copyright © 2018 Ankit Karna. All rights reserved.
//

import CoreData

public protocol DataStackConfirmable {
    var persistentContainer: NSPersistentContainer { get }
    var viewContext: NSManagedObjectContext { get }
    var savingContext: NSManagedObjectContext { get }
}

public class CoreDataStack: DataStackConfirmable {

    static let dbName = "BaxtaContactFramework"
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
    
    public static let shared = CoreDataStack()

    private init() {
        let container = Self.getPersistentContainer()
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Failed to load store: \(error)") }
        }

        self.persistentContainer = container
    }
    
    static func getPersistentContainer() -> NSPersistentContainer {
        let momdName = Self.dbName //pass this as a parameter
        guard let modelURL = Bundle(for: self).url(forResource: momdName, withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing mom from: \(modelURL)")
        }
        
        let container = NSPersistentContainer(name: Self.dbName, managedObjectModel: mom)
        return container
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
