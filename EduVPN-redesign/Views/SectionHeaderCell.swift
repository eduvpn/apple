//
//  SectionHeaderCell.swift
//  EduVPN
//
//  Created by Roopesh Chander on 24/06/20.
//  Copyright © 2020 SURFNet. All rights reserved.
//

class SectionHeaderCell: TableViewCell {
    func configure(as rowKind: ViewModelRowKind, isAdding: Bool) {
        var title: String {
            switch rowKind {
            case .serverByURLSectionHeaderKind:
                return isAdding ?
                    NSLocalizedString("Add your own server", comment: "") :
                    NSLocalizedString("Other servers", comment: "")
            case .instituteAccessServerSectionHeaderKind:
                return NSLocalizedString("Institute Access", comment: "")
            case .secureInternetOrgSectionHeaderKind, .secureInternetServerSectionHeaderKind:
                return NSLocalizedString("Secure Internet", comment: "")
            default:
                return ""
            }
        }

        var image: Image? {
            switch rowKind {
            case .serverByURLSectionHeaderKind:
                return Image(named: "SectionHeaderOwnServer")
            case .instituteAccessServerSectionHeaderKind:
                return Image(named: "SectionHeaderInstituteAccess")
            case .secureInternetOrgSectionHeaderKind, .secureInternetServerSectionHeaderKind:
                return Image(named: "SectionHeaderSecureInternet")
            default:
                return nil
            }
        }

        imageView?.image = image
        textField?.stringValue = title
    }
}
