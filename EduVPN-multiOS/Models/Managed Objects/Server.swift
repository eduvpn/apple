//
//  Server.swift
//  eduVPN
//

import Foundation
import CoreData

extension Server {

    func updateDisplayAndSortNames() {
        displayName = displayNames?.localizedValue ?? baseURI?.absoluteString ?? ""
        if isParent {
            sortName = "\(provider?.groupName ?? "") / \(displayName ?? "")"
        } else {
            sortName = "\(provider?.groupName ?? "") / \(parent?.displayName ?? "") / \(displayName ?? "")"
        }
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        updateDisplayAndSortNames()
    }
    
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        updateDisplayAndSortNames()
    }
    
    func update(with model: ServerModel) {
        guard let managedObjectContext = self.managedObjectContext else {
            return
        }
        self.baseURI = model.baseUri
        self.displayNames?.forEach { managedObjectContext.delete($0) }
        
        if let displayNames = model.displayNames {
            self.displayNames = Set(displayNames.compactMap { (displayData) -> DisplayName? in
                let displayName = DisplayName(context: managedObjectContext)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.server = self
                return displayName
            })
        } else if let displayNameString = model.displayName {
            let displayName = DisplayName(context: managedObjectContext)
            displayName.displayName = displayNameString
            displayName.server = self
        } else {
            self.displayNames = []
        }
    }
    
    func update(with model: PeerModel) {
        guard let managedObjectContext = self.managedObjectContext else {
            return
        }
        self.baseURI = model.baseUri
        self.displayNames?.forEach { managedObjectContext.delete($0) }
        
        if let displayNames = model.displayNames {
            self.displayNames = Set(displayNames.compactMap { (displayData) -> DisplayName? in
                let displayName = DisplayName(context: managedObjectContext)
                displayName.locale = displayData.key
                displayName.displayName = displayData.value
                displayName.server = self
                return displayName
            })
        } else if let displayNameString = model.displayName {
            let displayName = DisplayName(context: managedObjectContext)
            displayName.displayName = displayNameString
            displayName.server = self
        } else {
            self.displayNames = []
        }
    }
}
