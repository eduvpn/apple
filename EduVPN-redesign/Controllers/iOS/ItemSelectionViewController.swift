//
//  ItemSelectionViewController.swift
//  EduVPN
//

// A generic view controller for selecting an item from a list, modally.

import UIKit

protocol ItemSelectionViewControllerDelegate: class {
    func itemSelectionViewController(_ viewController: ItemSelectionViewController, didSelectIndex index: Int)
}

class ItemSelectionViewController: UITableViewController, ParametrizedViewController {

    struct Item {
        let imageName: String?
        let text: String

        init(_ text: String) {
            self.imageName = nil
            self.text = text
        }

        init(imageName: String, text: String) {
            self.imageName = imageName
            self.text = text
        }
    }

    struct Parameters {
        let items: [Item]
        let selectedIndex: Int
    }

    weak var delegate: ItemSelectionViewControllerDelegate?

    private var parameters: Parameters!
    private var selectedIndex: Int = -1

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
        self.selectedIndex = parameters.selectedIndex
    }

    override func viewDidLoad() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))
    }

    @objc func doneTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

extension ItemSelectionViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return parameters.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(UITableViewCell.self,
                                     identifier: "ItemSelectionCell",
                                     indexPath: indexPath)
        cell.textLabel?.text = parameters.items[indexPath.row].text
        if let imageName = parameters.items[indexPath.row].imageName {
            cell.imageView?.image = UIImage(named: imageName)
        } else {
            cell.imageView?.image = nil
        }
        if indexPath.row == selectedIndex {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let previousIndexPath = IndexPath(row: selectedIndex, section: 0)
        selectedIndex = indexPath.row
        tableView.reloadRows(at: [previousIndexPath, indexPath], with: .none)
        delegate?.itemSelectionViewController(self, didSelectIndex: indexPath.row)
    }
}
