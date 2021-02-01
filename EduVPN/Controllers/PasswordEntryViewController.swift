//
//  PasswordEntryViewController.swift
//  EduVPN

// Allows entry of password for OpenVPN configs that are configured to
// ask for password every time a connection is to be made.

final class PasswordEntryViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let configName: String
        let userName: String
        let initialPassword: String
    }

    private var parameters: Parameters!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }
}
