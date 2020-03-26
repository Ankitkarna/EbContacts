//
//  TableViewDataSource.swift
//  Moody
//
//  Created by Florian on 31/08/15.
//  Copyright © 2015 objc.io. All rights reserved.
//

import UIKit
import CoreData

public protocol TableViewDataSourceDelegate: AnyObject {
    associatedtype Object: NSFetchRequestResult
    associatedtype Cell: UITableViewCell
    associatedtype EmptyCell: UITableViewCell
    func configure(_ cell: Cell, for object: Object)
    func configureEmptyCell(_ cell: EmptyCell)
    //to do stuffs after objects have refreshed
    //default does nothing
    func objectDidRefresh()
}

extension TableViewDataSourceDelegate {
    public func objectDidRefresh() {}
}

private enum Update<Object>: CustomDebugStringConvertible {
    case insert(IndexPath, isSection: Bool)
    case update(IndexPath, Object)
    case move(IndexPath, IndexPath)
    case delete(IndexPath, isSection: Bool)

    var debugDescription: String {
        switch self {
        case .insert(let indexPath, _): return "Insert at \(indexPath)"
        case .update(let indexPath, _): return "update at \(indexPath)"
        case .move(let old, let new): return "move from \(old) to \(new)"
        case .delete(let indexPath, _): return "delete at \(indexPath)"
        }
    }
}

public class TableViewDataSource<Delegate: TableViewDataSourceDelegate>: NSObject, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    public typealias Object = Delegate.Object
    public typealias Cell = Delegate.Cell
    public typealias EmptyCell = Delegate.EmptyCell

    public required init(tableView: UITableView, fetchedResultsController: NSFetchedResultsController<Object>, delegate: Delegate) {
        self.tableView = tableView
        self.fetchedResultsController = fetchedResultsController
        self.delegate = delegate
        super.init()
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
        tableView.dataSource = self
        tableView.reloadData()
    }

    public var doForceReload = false

    public var selectedObject: Object? {
        guard let indexPath = tableView.indexPathForSelectedRow else { return nil }
        return objectAtIndexPath(indexPath)
    }

    public var totalObjects: [Object] {
        return fetchedResultsController.fetchedObjects ?? []
    }

    public func objectAtIndexPath(_ indexPath: IndexPath) -> Object {
        return fetchedResultsController.object(at: indexPath)
    }

    public var numberOfObjects: Int { return fetchedResultsController.fetchedObjects?.count ?? 0 }

    public func reconfigureFetchRequest(_ configure: (NSFetchRequest<Object>) -> Void) {
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: fetchedResultsController.cacheName)
        configure(fetchedResultsController.fetchRequest)
        do { try fetchedResultsController.performFetch() } catch { fatalError("fetch request failed") }
        tableView.reloadData()
    }

    // MARK: Private

    fileprivate let tableView: UITableView
    let fetchedResultsController: NSFetchedResultsController<Object>
    fileprivate weak var delegate: Delegate!

    private var updates: [Update<Object>] = []

    // MARK: UITableViewDataSource

    public func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = fetchedResultsController.sections?[section] else { return 0 }
        return section.numberOfObjects > 0 ? section.numberOfObjects : 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = fetchedResultsController.object(at: indexPath)
        let cell = tableView.dequeueCell(Cell.self, for: indexPath)
        delegate.configure(cell, for: object)
        return cell
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return fetchedResultsController.sections?[section].name
    }

    @available(iOS 11, *)
    private func processUpdatesForAboveiOS10(_ updates: [Update<Object>]?) {
        guard let updates = updates else { return tableView.reloadData() }

        tableView.performBatchUpdates({
            for update in updates {
                switch update {
                case .insert(let indexPath, let isSection):
                    if isSection {
                        tableView.insertSections([indexPath.section], with: .none)
                    } else {
                        tableView.insertRows(at: [indexPath], with: .none)
                    }
                case .update(let indexPath, _):
                    tableView.reloadRows(at: [indexPath], with: .none)
                case .move(let indexPath, let newIndexPath):
                    tableView.deleteRows(at: [indexPath], with: .none)
                    tableView.insertRows(at: [newIndexPath], with: .none)
                case .delete(let indexPath, let isSection):
                    if isSection {
                        tableView.deleteSections([indexPath.section], with: .none)
                    } else {
                        tableView.deleteRows(at: [indexPath], with: .none)
                    }
                }
            }
        }, completion: nil)
    }

    private func processUpdatesForUptoiOS10(_ updates: [Update<Object>]?) {
        guard let updates = updates else { return tableView.reloadData() }
        tableView.beginUpdates()
        for update in updates {
            switch update {
            case .insert(let indexPath, let isSection):
                if isSection {
                    tableView.insertSections([indexPath.section], with: .none)
                } else {
                    tableView.insertRows(at: [indexPath], with: .none)
                }
            case .update(let indexPath, _):
                tableView.reloadRows(at: [indexPath], with: .none)
            case .move(let indexPath, let newIndexPath):
                tableView.deleteRows(at: [indexPath], with: .none)
                tableView.insertRows(at: [newIndexPath], with: .none)
            case .delete(let indexPath, let isSection):
                if isSection {
                    tableView.deleteSections([indexPath.section], with: .none)
                } else {
                    tableView.deleteRows(at: [indexPath], with: .none)
                }
            }
        }
        tableView.endUpdates()
    }

    private func processUpdates(_ updates: [Update<Object>]?) {
        guard !doForceReload else { tableView.reloadData() ; return }
        tableView.reloadData()
         //processUpdatesForAboveiOS10(updates)
    }

    // MARK: NSFetchedResultsControllerDelegate

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updates = []
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let indexPath = IndexPath(item: 0, section: sectionIndex)
        switch type {
        case .insert:
            updates.append(.insert(indexPath, isSection: true))
        case .delete:
            updates.append(.delete(indexPath, isSection: true))
        default:
            break
        }
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let indexPath = newIndexPath else { fatalError("Index path should be not nil") }
            updates.append(.insert(indexPath, isSection: false))
        case .update:
            guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
            let object = objectAtIndexPath(indexPath)
            updates.append(.update(indexPath, object))
        case .move:
            guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
            guard let newIndexPath = newIndexPath else { fatalError("New index path should be not nil") }
            updates.append(.move(indexPath, newIndexPath))
        case .delete:
            guard let indexPath = indexPath else { fatalError("Index path should be not nil") }
            updates.append(.delete(indexPath, isSection: false))
        @unknown default: break
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        processUpdates(updates)
        delegate?.objectDidRefresh()
    }
}
