//
//  NSManagedObjectContext+SaveHelpers.swift
//  EduVPN
//

import CoreData

public enum SuccessResult {
    /// A success case
    case success
    /// A failure case with associated ErrorType instance
    case failure(Swift.Error)
}

public typealias SaveResult = SuccessResult
public typealias CoreDataStackSaveCompletion = (SaveResult) -> Void

/**
 Convenience extension to `NSManagedObjectContext` that ensures that saves to contexts of type
 `MainQueueConcurrencyType` and `PrivateQueueConcurrencyType` are dispatched on the correct GCD queue.
 */
public extension NSManagedObjectContext {
    
    /**
     Convenience method to asynchronously save the `NSManagedObjectContext` if changes are present.
     Method also ensures that the save is executed on the correct queue when using Main/Private queue concurrency types.
     - parameter completion: Completion closure with a `SaveResult` to be executed upon the completion of the save operation.
     */
    func saveContext(_ completion: CoreDataStackSaveCompletion? = nil) {
        func saveFlow() {
            do {
                try sharedSaveFlow()
                completion?(.success)
            } catch let saveError {
                completion?(.failure(saveError))
            }
        }
        
        switch concurrencyType {
            
        case .confinementConcurrencyType:
            saveFlow()
            
        case .privateQueueConcurrencyType,
             .mainQueueConcurrencyType:
            perform(saveFlow)
            
        @unknown default:
            fatalError()
            
        }
    }
    
    
    /**
     Convenience method to asynchronously save the `NSManagedObjectContext` if changes are present.
     If any parent contexts are found, they too will be saved asynchronously.
     Method also ensures that the save is executed on the correct queue when using Main/Private queue concurrency types.
     - parameter completion: Completion closure with a `SaveResult` to be executed
     either upon the completion of the top most context's save operation or the first encountered save error.
     */
    func saveContextToStore(_ completion: CoreDataStackSaveCompletion? = nil) {
        func saveFlow() {
            do {
                try sharedSaveFlow()
                if let parentContext = parent {
                    parentContext.saveContextToStore(completion)
                } else {
                    completion?(.success)
                }
            } catch let saveError {
                completion?(.failure(saveError))
            }
        }
        
        switch concurrencyType {
            
        case .confinementConcurrencyType:
            saveFlow()
            
        case .privateQueueConcurrencyType,
             .mainQueueConcurrencyType:
            perform(saveFlow)
            
        @unknown default:
            fatalError()
            
        }
    }
    
    private func sharedSaveFlow() throws {
        guard hasChanges else {
            return
        }
        
        try save()
    }
}
