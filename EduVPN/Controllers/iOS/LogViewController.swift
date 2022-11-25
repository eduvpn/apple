//
//  LogViewController.swift
//  EduVPN
//

import UIKit
import PromiseKit

class LogViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
    }

    private var parameters: Parameters!

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var announcementView: UIView!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
        announcementView.isHidden = true
        announcementView.layer.cornerRadius = 15
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Copy Log", comment: ""),
            style: .plain,
            target: self, action: #selector(copyLogTapped(_:)))
        loadLog()
    }

    private func loadLog() {
        let loggingService = parameters.environment.loggingService
        firstly {
            loggingService.getLog()
        }.map { [weak self] log in
            if let textView = self?.textView {
                textView.text = log ?? ""
            }
        }.cauterize()
    }

    @objc func copyLogTapped(_ sender: Any) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = textView.text
        showTransientAnnouncement()
    }

    private func showTransientAnnouncement() {
        // Show and hide the announcement that says "Copied"
        announcementView.isHidden = false
        announcementView.alpha = 0.0
        UIView.animate(
            withDuration: 0.6,
            animations: { [weak announcementView] in
            announcementView?.alpha = 0.6
            }, completion: { [weak announcementView] _ in
                UIView.animate(
                    withDuration: 0.6,
                    animations: { [weak announcementView] in
                        announcementView?.alpha = 0
                    }, completion: { [weak announcementView] _ in
                        announcementView?.isHidden = true
                    })
            })
    }
}
