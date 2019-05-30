//
//  CoreDataFetchedResultsControllerDelegate.swift
//  EduVPN-macOS
//
//  Created by Aleksandr Poddubny on 30/05/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Cocoa
import CoreData

class CoreDataFetchedResultsControllerDelegate<T: NSManagedObject>: NSObject, FetchedResultsControllerDelegate {
    
    private weak var tableView: DeselectingTableView?
    
    // MARK: - Lifecycle
    init(tableView: DeselectingTableView) {
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
        
        fatalError("This should not happen in macOS")
    }
}
