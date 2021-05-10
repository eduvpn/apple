//
//  SectionHeaderCell.swift
//  EduVPN
//

import Foundation

#if os(iOS)
import UIKit
#endif

class SectionHeaderCell: TableViewCell {

    #if os(iOS)
    @IBOutlet weak var rowImageView: UIImageView!
    @IBOutlet weak var rowLabel: UILabel!
    #endif

    func configure(as rowKind: ViewModelRowKind, isAdding: Bool) {
        var title: String {
            switch rowKind {
            case .otherServerSectionHeaderKind:
                return isAdding ?
                    NSLocalizedString("Add your own server", comment: "list section header") :
                    NSLocalizedString("Other servers", comment: "list section header")
            case .instituteAccessServerSectionHeaderKind:
                return NSLocalizedString("Institute Access", comment: "list section header")
            case .secureInternetOrgSectionHeaderKind, .secureInternetServerSectionHeaderKind:
                return NSLocalizedString("Secure Internet", comment: "list section header")
            default:
                return ""
            }
        }

        var image: Image? {
            switch rowKind {
            case .otherServerSectionHeaderKind:
                return Image(named: "SectionHeaderOwnServer")
            case .instituteAccessServerSectionHeaderKind:
                return Image(named: "SectionHeaderInstituteAccess")
            case .secureInternetOrgSectionHeaderKind, .secureInternetServerSectionHeaderKind:
                return Image(named: "SectionHeaderSecureInternet")
            default:
                return nil
            }
        }

        #if os(macOS)
        imageView?.image = image
        textField?.stringValue = title
        #elseif os(iOS)
        prepareForReuse()
        rowImageView?.image = image
        rowLabel?.text = title
        #endif
    }
}
