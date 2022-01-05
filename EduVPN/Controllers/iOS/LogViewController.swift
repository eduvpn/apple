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
}
