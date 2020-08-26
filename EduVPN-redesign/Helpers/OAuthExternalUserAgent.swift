//
//  OAuthExternalUserAgent.swift
//  EduVPN
//

import Foundation
import AppAuth

#if os(macOS)
class OAuthExternalUserAgent: NSObject, OIDExternalUserAgent {
    private var isExternalUserAgentFlowInProgress = false

    init(presentingViewController: AuthorizingViewController) {
    }

    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        if isExternalUserAgentFlowInProgress {
            return false
        }
        guard let requestURL = request.externalUserAgentRequestURL() else {
            return false
        }

        isExternalUserAgentFlowInProgress = true
        guard NSWorkspace.shared.open(requestURL) else {
            isExternalUserAgentFlowInProgress = false
            session.failExternalUserAgentFlowWithError(
                OIDErrorUtilities.error(
                    with: .browserOpenError,
                    underlyingError: nil,
                    description: "Unable to open the browser."))
            return false
        }
        return true
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        isExternalUserAgentFlowInProgress = false
        completion()
    }
}
#endif
