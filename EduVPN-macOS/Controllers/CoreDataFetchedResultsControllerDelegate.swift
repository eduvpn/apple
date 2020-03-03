//
//  CoreDataFetchedResultsControllerDelegate.swift
//  EduVPN-macOS
//

import Cocoa
import CoreData

class CoreDataFetchedResultsControllerDelegate<T: NSManagedObject>: NSObject, FetchedResultsControllerDelegate {
    
    private weak var tableView: DeselectingTableView?
    let sectioned: Bool
    
    // MARK: - Lifecycle
    init(tableView: DeselectingTableView, sectioned: Bool = false) {
        self.tableView = tableView
        self.sectioned = sectioned
    }
    
    func fetchedResultsControllerDidPerformFetch(_ controller: FetchedResultsController<T>) {
        tableView?.reloadData()
    }
    
    func fetchedResultsControllerWillChangeContent(_ controller: FetchedResultsController<T>) {
        guard !sectioned else {
            return
        }
        tableView?.beginUpdates()
    }
    
    func fetchedResultsControllerDidChangeContent(_ controller: FetchedResultsController<T>) {
        guard !sectioned else {
            // NSTableView on macOS doesn't support sections, thus simply reload whole table view
            tableView?.reloadData()
            return
        }
        
        tableView?.endUpdates()
    }
    
    func fetchedResultsController(_ controller: FetchedResultsController<T>,
                                  didChangeObject change: FetchedResultsObjectChange<T>) {
        guard !sectioned else {
            return
        }
        
        guard let tableView = tableView else { return }
        
        switch change {
            
        case let .insert(_, indexPath):
            tableView.insertRows(at: IndexSet(integer: indexPath.item), withAnimation: .effectFade)
            
        case let .delete(_, indexPath):
            tableView.removeRows(at: IndexSet(integer: indexPath.item), withAnimation: .effectFade)
            
        case let .move(_, fromIndexPath, toIndexPath):
            tableView.removeRows(at: [fromIndexPath.item], withAnimation: .effectFade)
            tableView.insertRows(at: [toIndexPath.item], withAnimation: .effectFade)
            
        case let .update(_, indexPath):
            let columnIndexes = IndexSet(integersIn: 0..<tableView.numberOfColumns)
            tableView.reloadData(forRowIndexes: IndexSet(integer: indexPath.item), columnIndexes: columnIndexes)
            
        }
    }
    
    func fetchedResultsController(_ controller: FetchedResultsController<T>,
                                  didChangeSection change: FetchedResultsSectionChange<T>) {
        // macOS doesn't support sections, thus simply reload whole table view
        tableView?.reloadData()
    }
}
