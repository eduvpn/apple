//
//  CoreDataFetchedResultsControllerDelegate.swift
//  eduVPN
//

import CoreData
import UIKit

class CoreDataFetchedResultsControllerDelegate<T: NSManagedObject>: NSObject, FetchedResultsControllerDelegate {
    
    private weak var tableView: UITableView?
    
    // MARK: - Lifecycle
    init(tableView: UITableView) {
        self.tableView = tableView
    }
    
    func fetchedResultsControllerDidPerformFetch(_ controller: FetchedResultsController<T>) {
        tableView?.reloadData()
    }
    
    func fetchedResultsControllerWillChangeContent(_ controller: FetchedResultsController<T>) {
        tableView?.beginUpdates()
    }
    
    func fetchedResultsControllerDidChangeContent(_ controller: FetchedResultsController<T>) {
        tableView?.endUpdates()
    }
    
    func fetchedResultsController(_ controller: FetchedResultsController<T>,
                                  didChangeObject change: FetchedResultsObjectChange<T>) {
        
        guard let tableView = tableView else { return }
        
        switch change {
            
        case let .insert(_, indexPath):
            tableView.insertRows(at: [indexPath], with: .automatic)
            
        case let .delete(_, indexPath):
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
        case let .move(_, fromIndexPath, toIndexPath):
            tableView.moveRow(at: fromIndexPath, to: toIndexPath)
            
        case let .update(_, indexPath):
            tableView.reloadRows(at: [indexPath], with: .automatic)
            
        }
    }
    
    func fetchedResultsController(_ controller: FetchedResultsController<T>,
                                  didChangeSection change: FetchedResultsSectionChange<T>) {
        
        guard let tableView = tableView else { return }
        
        switch change {
            
        case let .insert(_, index):
            tableView.insertSections(IndexSet(integer: index), with: .automatic)
            
        case let .delete(_, index):
            tableView.deleteSections(IndexSet(integer: index), with: .automatic)
            
        }
    }
}
