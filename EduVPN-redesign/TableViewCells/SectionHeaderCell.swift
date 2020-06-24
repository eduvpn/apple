//
//  SectionHeaderCell.swift
//  EduVPN
//
//  Created by Roopesh Chander on 24/06/20.
//  Copyright © 2020 SURFNet. All rights reserved.
//

class SectionHeaderCell: TableViewCell {
    func configure(as rowKind: ViewModelRowKind) {
        var title: String {
            switch rowKind {
            case .addingServerByURLSectionHeaderKind:
                return NSLocalizedString("Add your own server", comment: "")
            case .instituteAccessServerSectionHeaderKind:
                return NSLocalizedString("Institute access", comment: "")
            case .secureInternetOrgSectionHeaderKind:
                return NSLocalizedString("Secure internet", comment: "")
            default:
                return ""
            }
        }
        textField?.stringValue = title
    }
}
