//
//  ServersViewController.swift
//  EduVPN
//

import UIKit
import os.log
import CoreData

protocol ServersViewControllerDelegate: class {
    func serversViewControllerNoProfiles(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, addProviderAnimated animated: Bool, allowClose: Bool)
    func serversViewControllerAddPredefinedProvider(_ controller: ServersViewController)
    func serversViewController(_ controller: ServersViewController, didSelect instance: Server)
    func serversViewController(_ controller: ServersViewController, didDelete instance: Server)
    func serversViewController(_ controller: ServersViewController, didDelete organization: Organization)
}

class ServersViewController: UITableViewController {

    weak var delegate: ServersViewControllerDelegate?

    @IBOutlet var unreachableLabel: UILabel?

    @IBOutlet var otherProviderButton: UIButton?

    var viewContext: NSManagedObjectContext!

    private lazy var fetchedResultsController: FetchedResultsController<Server> = {
        let fetchRequest = NSFetchRequest<Server>()
        fetchRequest.entity = Server.entity()
        fetchRequest.predicate = NSPredicate(format: "provider != NIL AND (isParent == TRUE OR parent.isExpanded == TRUE)")

        let sortDescriptors = [NSSortDescriptor(key: "sortName", ascending: true)]
        fetchRequest.sortDescriptors = sortDescriptors

        let frc = FetchedResultsController<Server>(fetchRequest: fetchRequest,
                                                     managedObjectContext: viewContext,
                                                     sectionNameKeyPath: "provider.groupName")
        frc.setDelegate(self.frcDelegate)

        return frc
    }()

    private lazy var frcDelegate: CoreDataFetchedResultsControllerDelegate<Server> = { // swiftlint:disable:this weak_delegate
        return CoreDataFetchedResultsControllerDelegate<Server>(tableView: self.tableView)
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refresh()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()
    }

    @objc func refresh(animated: Bool = false) {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            os_log("Failed to fetch objects: %{public}@", log: Log.general, type: .error, error.localizedDescription)
        }
    }

    @IBAction func addOtherProvider(_ sender: Any) {
        delegate?.serversViewController(self, addProviderAnimated: true, allowClose: true)
    }

}

// MARK: - TableView

extension ServersViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }
        let section = sections[section]
        return section.name
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let serverCell = tableView.dequeueReusableCell(type: ServerTableViewCell.self, for: indexPath)

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let server = section.objects[indexPath.row]

        serverCell.configure(with: server)

        return serverCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let instance = section.objects[indexPath.row]

        delegate?.serversViewController(self, didSelect: instance)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // TODO re-enable editing. But first need to make sure handling of instances and organizations is complete
        return false
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            guard let sections = fetchedResultsController.sections else {
                fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
            }

            let section = sections[indexPath.section]
            let instance = section.objects[indexPath.row]

            delegate?.serversViewController(self, didDelete: instance)
        }
    }

}

class ServerTableViewCell: UITableViewCell {
    func configure(with server: Server) {
        switch server.provider {
        case is Organization:
            imageView?.image = (!server.isParent || server.children?.count ?? 0 > 0) ? UIImage(named: "Secure Internet") :  UIImage(named: "Institute Access")
            imageView?.isHidden = false
        case is Custom:
            imageView?.image = UIImage(named: "Other")
            imageView?.isHidden = false
        default:
            imageView?.image = nil
            imageView?.isHidden = true
        }

        textLabel?.text = server.displayName ?? "-"
    }
}

extension ServerTableViewCell: Identifiable {}
