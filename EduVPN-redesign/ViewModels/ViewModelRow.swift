//
//  ViewModelRow.swift
//  EduVPN
//

enum ViewModelRowKind: Int {
    case addingServerByURLSectionHeaderKind
    case addingServerByURLKind
    case instituteAccessServerSectionHeaderKind
    case instituteAccessServerKind
    case secureInternetOrgSectionHeaderKind
    case secureInternetOrgKind
}

struct RowsDifference<T: ViewModelRow> {
    let deletedIndices: [Int]
    let insertions: [(Int, T)]
}

protocol ViewModelRow: Comparable {
    var rowKind: ViewModelRowKind { get }
    var displayName: String { get }
}

func < <T: ViewModelRow>(lhs: T, rhs: T) -> Bool {
    if lhs.rowKind.rawValue < rhs.rowKind.rawValue {
        return true
    }
    if lhs.rowKind.rawValue > rhs.rowKind.rawValue {
        return false
    }
    return lhs.displayName < rhs.displayName
}

func == <T: ViewModelRow>(lhs: T, rhs: T) -> Bool {
    return (lhs.rowKind == rhs.rowKind) && (lhs.displayName == rhs.displayName)
}

extension Array where Array.Element: ViewModelRow {
    // Consider replacing with BidirectionalCollection.difference(to:)
    // when we can update to Swift 5.1
    func rowsDifference(from other: [Array.Element]) -> RowsDifference<Array.Element> {
        var deletedIndices: [Int] = []
        var insertions: [(Int, Array.Element)] = []
        var thisIndex = 0
        var otherIndex = 0
        while thisIndex < count && otherIndex < other.count {
            if other[otherIndex] < self[thisIndex] {
                deletedIndices.append(otherIndex)
                otherIndex += 1
            } else if other[otherIndex] > self[thisIndex] {
                insertions.append((thisIndex, self[thisIndex]))
                thisIndex += 1
            } else {
                otherIndex += 1
                thisIndex += 1
            }
        }
        return RowsDifference(deletedIndices: deletedIndices, insertions: insertions)
    }
}
