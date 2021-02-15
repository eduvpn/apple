//
//  AddServerViewController.swift
//  EduVPN
//

#if os(macOS)
import AppKit
#endif

protocol AddServerViewControllerDelegate: class {
    func addServerViewController(
        _ controller: AddServerViewController,
        addedSimpleServerWithBaseURL baseURLString: DiscoveryData.BaseURLString,
        authState: AuthState)
}

final class AddServerViewController: ViewController, ParametrizedViewController {
    struct Parameters {
        let environment: Environment
        let preDefinedProvider: PreDefinedProvider?
    }

    weak var delegate: AddServerViewControllerDelegate?

    private var parameters: Parameters!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }
}
