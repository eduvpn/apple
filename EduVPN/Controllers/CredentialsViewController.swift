//
//  CredentialsViewController.swift
//  EduVPN

// Allows entry of username / password for OpenVPN configs
// that require that.

final class CredentialsViewController: ViewController, ParametrizedViewController {

    struct Parameters {
        let initialCredentials: OpenVPNConfigCredentials?
    }

    private var parameters: Parameters!

    func initializeParameters(_ parameters: Parameters) {
        guard self.parameters == nil else {
            fatalError("Can't initialize parameters twice")
        }
        self.parameters = parameters
    }
}
