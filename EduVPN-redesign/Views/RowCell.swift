//
//  RowCell.swift
//  EduVPN
//

class RowCell: TableViewCell {
    func configure<T: ViewModelRow>(with row: T) {
        textField?.stringValue = row.displayName
    }
}
