//
//  ViewModelRow.swift
//  EduVPN
//

enum ViewModelRowKind: Int {
    case instituteAccessServerSectionHeaderKind
    case instituteAccessServerKind
    case secureInternetOrgSectionHeaderKind
    case secureInternetOrgKind
    case secureInternetServerSectionHeaderKind
    case secureInternetServerKind
    case otherServerSectionHeaderKind
    case serverByURLKind
    case openVPNConfigKind
    case noResultsKind

    var isSectionHeader: Bool {
        switch self {
        case .otherServerSectionHeaderKind,
             .instituteAccessServerSectionHeaderKind,
             .secureInternetOrgSectionHeaderKind,
             .secureInternetServerSectionHeaderKind:
            return true
        default:
            return false
        }
    }

    var isServerRow: Bool {
        switch self {
        case .instituteAccessServerKind,
             .secureInternetOrgKind,
             .secureInternetServerKind,
             .serverByURLKind,
             .openVPNConfigKind:
            return true
        default:
            return false
        }
    }
}

struct RowsDifference<T: ViewModelRow> {
    let deletedIndices: [Int]
    let insertions: [(Int, T)]
}

protocol ViewModelRow: Comparable {
    var rowKind: ViewModelRowKind { get }
    var displayText: String { get }
}

func < <T: ViewModelRow>(lhs: T, rhs: T) -> Bool {
    if lhs.rowKind.rawValue < rhs.rowKind.rawValue {
        return true
    }
    if lhs.rowKind.rawValue > rhs.rowKind.rawValue {
        return false
    }
    return lhs.displayText < rhs.displayText
}

func == <T: ViewModelRow>(lhs: T, rhs: T) -> Bool {
    return (lhs.rowKind == rhs.rowKind) && (lhs.displayText == rhs.displayText)
}

extension Array where Array.Element: ViewModelRow {
    // Consider replacing with BidirectionalCollection.difference(to:)
    // when we can update to Swift 5.1
    func rowsDifference(from other: [Array.Element]) -> RowsDifference<Array.Element> {
        var deletedIndices: [Int] = []
        var insertions: [(Int, Array.Element)] = []
        var thisIndex = 0
        var otherIndex = 0
        while otherIndex < other.count && thisIndex < count {
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
        while otherIndex < other.count {
            deletedIndices.append(otherIndex)
            otherIndex += 1
        }
        while thisIndex < count {
            insertions.append((thisIndex, self[thisIndex]))
            thisIndex += 1
        }
        return RowsDifference(deletedIndices: deletedIndices, insertions: insertions)
    }

    func applying(diff: RowsDifference<Array.Element>) -> Array {
        var copy = self
        for index in diff.deletedIndices.sorted().reversed() {
            copy.remove(at: index)
        }
        for insertion in diff.insertions.sorted(by: { $0.0 < $1.0 }) {
            copy.insert(insertion.1, at: insertion.0)
        }
        return copy
    }
}
