//
//  ConnectionInfoViewController.swift
//  EduVPN
//

import UIKit

class ConnectionInfoViewController: UITableViewController, ParametrizedViewController {
    enum ConnectionInfoRow: Int {
        case duration = 0
        case dataTransferred = 1
        case address = 2
        case profileName = 3

        var title: String {
            switch self {
            case .duration: return NSLocalizedString("DURATION", comment: "")
            case .dataTransferred: return NSLocalizedString("DATA TRANSFERRED", comment: "")
            case .address: return NSLocalizedString("ADDRESS", comment: "")
            case .profileName: return NSLocalizedString("PROFILE", comment: "")
            }
        }

        func value(from connectionInfo: ConnectionInfoHelper.ConnectionInfo) -> String {
            switch self {
            case .duration: return connectionInfo.duration
            case .dataTransferred: return connectionInfo.dataTransferred
            case .address: return connectionInfo.addresses
            case .profileName: return connectionInfo.profileName ?? ""
            }
        }
    }

    struct Parameters {
        let connectionInfo: ConnectionInfoHelper.ConnectionInfo
    }

    var connectionInfo: ConnectionInfoHelper.ConnectionInfo? {
        didSet(oldValue) {
            // The profile name doesn't change, so we don't reload that.
            // If the address has changed, reload it, else leave it as it is,
            // so that the copy context menu doesn't get dismissed.
            if oldValue?.addresses == connectionInfo?.addresses {
                tableView.reloadRows(indices: [
                    ConnectionInfoRow.duration.rawValue,
                    ConnectionInfoRow.dataTransferred.rawValue])
            } else {
                tableView.reloadRows(indices: [
                    ConnectionInfoRow.duration.rawValue,
                    ConnectionInfoRow.dataTransferred.rawValue,
                    ConnectionInfoRow.address.rawValue])
            }
        }
    }

    func initializeParameters(_ parameters: Parameters) {
        guard self.connectionInfo == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.connectionInfo = parameters.connectionInfo
    }
}

extension ConnectionInfoViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if connectionInfo?.profileName == nil {
            return 3
        }
        return 4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(ConnectionInfoCell.self,
                                     identifier: "ConnectionInfoCell",
                                     indexPath: indexPath)
        if let row = ConnectionInfoRow(rawValue: indexPath.row),
            let connectionInfo = self.connectionInfo {
            cell.titleLabel.text = row.title
            cell.valueLabel.text = row.value(from: connectionInfo)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
}

extension ConnectionInfoViewController {
    // Enable copying of the address and profile.
    // Consider replacing with tableView(_:contextMenuConfigurationForRowAt:point:)
    // when we move to min deployment target of iOS 13.
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        guard let row = ConnectionInfoRow(rawValue: indexPath.row) else { return false }
        return (row == .address) || (row == .profileName)
    }

    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        guard let row = ConnectionInfoRow(rawValue: indexPath.row) else { return false }
        guard (row == .address) || (row == .profileName) else { return false }
        return action == #selector(copy(_:))
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        guard let row = ConnectionInfoRow(rawValue: indexPath.row) else { return }
        if action == #selector(copy(_:)) {
            switch row {
            case .address:
                let address = (self.connectionInfo?.addresses ?? "")
                    .replacingOccurrences(of: "\n", with: " ")
                UIPasteboard.general.string = address
            case .profileName:
                UIPasteboard.general.string = self.connectionInfo?.profileName ?? ""
            default:
                break
            }
        }
    }
}

class ConnectionInfoCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
}
