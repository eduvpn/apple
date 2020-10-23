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
            tableView.reloadRows(indices: [0, 1, 2])
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

class ConnectionInfoCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
}
