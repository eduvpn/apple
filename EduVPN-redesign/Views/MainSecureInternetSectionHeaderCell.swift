//
//  MainSecureInternetSectionHeaderCell.swift
//  EduVPN
//

#if os(macOS)
import AppKit

class MainSecureInternetSectionHeaderCell: SectionHeaderCell {

    private struct ServerEntry {
        let baseURLString: DiscoveryData.BaseURLString
        let countryName: String
    }

    private var selectedBaseURLString: DiscoveryData.BaseURLString?
    private var onLocationChanged: ((DiscoveryData.BaseURLString) -> Void)?

    private var pullDownServerEntries: [ServerEntry] = []

    @IBOutlet weak var changeLocationPullDown: NSPopUpButton!

    func configureMainSecureInternetSectionHeader(
        serversMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer],
        selectedBaseURLString: DiscoveryData.BaseURLString,
        onLocationChanged: @escaping (DiscoveryData.BaseURLString) -> Void) {

        super.configure(as: .secureInternetServerSectionHeaderKind, isAdding: false)

        self.selectedBaseURLString = selectedBaseURLString
        self.onLocationChanged = onLocationChanged

        var serverEntries: [ServerEntry] = []
        for server in serversMap.values {
            let serverEntry = ServerEntry(
                baseURLString: server.baseURLString,
                countryName: Locale.current.localizedString(forRegionCode: server.countryCode) ?? "Unknown country")
            serverEntries.append(serverEntry)
        }
        serverEntries.sort { $0.countryName < $1.countryName }
        self.pullDownServerEntries = serverEntries

        changeLocationPullDown.removeAllItems()
        if let menu = changeLocationPullDown.menu {
            let buttonTitle = NSLocalizedString("Change Location", comment: "")
            menu.addItem(NSMenuItem(title: buttonTitle, action: nil, keyEquivalent: ""))
            for (index, serverEntry) in serverEntries.enumerated() {
                let menuItem = NSMenuItem(
                    title: serverEntry.countryName,
                    action: #selector(locationSelected(sender:)),
                    keyEquivalent: "")
                menuItem.state = (serverEntry.baseURLString == selectedBaseURLString) ? .on : .off
                menuItem.target = self
                menuItem.tag = index
                menu.addItem(menuItem)
            }
        }
    }

    @objc func locationSelected(sender: Any) {
        guard let menuItem = sender as? NSMenuItem else { return }
        guard menuItem.tag < pullDownServerEntries.count else { return }
        let serverEntry = pullDownServerEntries[menuItem.tag]
        if serverEntry.baseURLString != selectedBaseURLString {
            onLocationChanged?(serverEntry.baseURLString)
        }
    }
}
#endif
