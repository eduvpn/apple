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
                return NSLocalizedString("Institute Access", comment: "")
            case .secureInternetOrgSectionHeaderKind:
                return NSLocalizedString("Secure Internet", comment: "")
            default:
                return ""
            }
        }

        var image: Image? {
            switch rowKind {
            case .addingServerByURLSectionHeaderKind:
                return Image(named: "SectionHeaderOwnServer")
            case .instituteAccessServerSectionHeaderKind:
                return Image(named: "SectionHeaderInstituteAccess")
            case .secureInternetOrgSectionHeaderKind:
                return Image(named: "SectionHeaderSecureInternet")
            default:
                return nil
            }
        }

        imageView?.image = image
        textField?.stringValue = title
    }
}
