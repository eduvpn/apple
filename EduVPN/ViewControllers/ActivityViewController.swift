//
//  ActivityViewController.swift
//  EduVPN
//

import UIKit

struct ActivityViewModel {
    let infoString: String
}

class ActivityViewController: UIViewController {
    var activityViewModel: ActivityViewModel? {
        didSet {
            pushViewModel()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        pushViewModel()
        activityIndicator?.startAnimating()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        activityViewModel = nil
        activityIndicator?.stopAnimating()
    }
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var infoLabel: UILabel!

    private func pushViewModel() {
        infoLabel?.text = activityViewModel?.infoString
        activityIndicator?.startAnimating()
    }
}

extension ActivityViewController: Identifiable {}
