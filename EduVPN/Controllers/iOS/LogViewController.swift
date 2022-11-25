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

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }

    override func viewDidLoad() {
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
    }
}
