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
            title = countryName
            image = Image(named: "CountryFlag_\(displayInfo.flagCountryCode)")
        } else {
            title = row.displayText
        }
        #if os(macOS)
        textField?.stringValue = title
        imageView?.image = image
        setAccessibilityLabel(title)
        #elseif os(iOS)
        textLabel?.text = title
        imageView?.image = image
        accessibilityLabel = title
        #endif
    }
}
