//
//  RowCell.swift
//  EduVPN
//

class RowCell: TableViewCell {
    func configure<T: ViewModelRow>(with row: T) {
        if let mainRow = row as? MainViewModel.Row,
            case .secureInternetServer(_, let countryCode, let countryName) = mainRow {
            textField?.stringValue = countryName
            imageView?.image = Image(named: "CountryFlag_\(countryCode)")
        } else {
            textField?.stringValue = row.displayText
        }
    }
}
