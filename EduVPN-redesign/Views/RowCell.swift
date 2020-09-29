//
//  RowCell.swift
//  EduVPN
//

class RowCell: TableViewCell {
    func configure<T: ViewModelRow>(with row: T) {
        let title: String
        var image: Image?
        if let mainRow = row as? MainViewModel.Row,
            case .secureInternetServer(_, let displayInfo, let countryName) = mainRow {
            #if os(macOS)
            textField?.stringValue = countryName
            imageView?.image = Image(named: "CountryFlag_\(displayInfo.flagCountryCode)")
            #endif
        } else {
            #if os(macOS)
            textField?.stringValue = row.displayText
            #endif
        }
    }
}
