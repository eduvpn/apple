//
//  MainSecureInternetSectionHeaderCell.swift
//  EduVPN
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

class MainSecureInternetSectionHeaderCell: SectionHeaderCell {

    private struct ServerEntry {
        let baseURLString: DiscoveryData.BaseURLString
        let countryCode: String
        let countryName: String
    }

    private var selectedBaseURLString: DiscoveryData.BaseURLString?
    private var onLocationChanged: ((DiscoveryData.BaseURLString) -> Void)?

    private var serverEntries: [ServerEntry] = []

    #if os(macOS)
    @IBOutlet weak var changeLocationPullDown: NSPopUpButton!
    #endif

    #if os(iOS)
    private weak var environment: Environment?
    private weak var containingViewController: ViewController?
    private var selectedIndex: Int = -1
    #endif

    func configureMainSecureInternetSectionHeader(
        environment: Environment,
        containingViewController: ViewController,
        serversMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer],
        selectedBaseURLString: DiscoveryData.BaseURLString,
        onLocationChanged: @escaping (DiscoveryData.BaseURLString) -> Void) {

        super.configure(as: .secureInternetServerSectionHeaderKind, isAdding: false)

        #if os(iOS)
        self.environment = environment
        self.containingViewController = containingViewController
        #endif

        self.selectedBaseURLString = selectedBaseURLString
        self.onLocationChanged = onLocationChanged

        var serverEntries: [ServerEntry] = []
        for server in serversMap.values {
            let serverEntry = ServerEntry(
                baseURLString: server.baseURLString,
                countryCode: server.countryCode,
                countryName: Locale.current.localizedString(forRegionCode: server.countryCode) ??
                    NSLocalizedString(
                        "Unknown country",
                        comment: "unknown country code"))
            serverEntries.append(serverEntry)
        }
        serverEntries.sort { $0.countryName < $1.countryName }
        self.serverEntries = serverEntries

        #if os(macOS)
        changeLocationPullDown.removeAllItems()
        if let menu = changeLocationPullDown.menu {
            let buttonTitle = NSLocalizedString(
                "Change Location",
                comment: "macOS main list change location pull-down menu title")
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
        #elseif os(iOS)
        for (index, serverEntry) in serverEntries.enumerated() {
            // Using an 'if' is clearer than a 'where' here.
            // swiftlint:disable:next for_where
            if serverEntry.baseURLString == selectedBaseURLString {
                selectedIndex = index
            }
        }
        #endif
    }

    #if os(macOS)
    @objc func locationSelected(sender: Any) {
        guard let menuItem = sender as? NSMenuItem else { return }
        guard menuItem.tag < serverEntries.count else { return }
        let serverEntry = serverEntries[menuItem.tag]
        if serverEntry.baseURLString != selectedBaseURLString {
            onLocationChanged?(serverEntry.baseURLString)
        }
    }
    #endif

    #if os(iOS)
    @IBAction func changeLocationTapped(_ sender: Any) {
        guard let environment = self.environment,
            let containingViewController = self.containingViewController else {
                return
        }
        var items: [ItemSelectionViewController.Item] = []
        for serverEntry in serverEntries {
            let item = ItemSelectionViewController.Item(
                imageName: "CountryFlag_\(serverEntry.countryCode)",
                text: serverEntry.countryName)
            items.append(item)
        }
        let selectionVC = environment.instantiateItemSelectionViewController(
            items: items, selectedIndex: selectedIndex)
        selectionVC.title = NSLocalizedString(
            "Select a location",
            comment: "iOS location selection view title")
        selectionVC.delegate = self
        let navigationVC = UINavigationController(rootViewController: selectionVC)
        navigationVC.modalPresentationStyle = .pageSheet
        containingViewController.present(navigationVC, animated: true, completion: nil)
    }
    #endif
}

#if os(iOS)
extension MainSecureInternetSectionHeaderCell: ItemSelectionViewControllerDelegate {
    func itemSelectionViewController(_ viewController: ItemSelectionViewController, didSelectIndex index: Int) {
        guard index >= 0 && index < serverEntries.count else { return }
        let serverEntry = serverEntries[index]
        if serverEntry.baseURLString != selectedBaseURLString {
            onLocationChanged?(serverEntry.baseURLString)
        }
    }
}
#endif
