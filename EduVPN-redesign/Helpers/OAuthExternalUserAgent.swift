//
//  OAuthExternalUserAgent.swift
//  EduVPN
//

import Foundation
import AppAuth

#if os(macOS)
class OAuthExternalUserAgent: NSObject, OIDExternalUserAgent {
    private var isExternalUserAgentFlowInProgress = false
    private var wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?

    init(presentingViewController: AuthorizingViewController,
         wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?) {
        self.wayfSkippingInfo = wayfSkippingInfo
    }

    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        if isExternalUserAgentFlowInProgress {
            return false
        }
        guard let requestURL = request.externalUserAgentRequestURL() else {
            return false
        }

        isExternalUserAgentFlowInProgress = true
        let urlToOpen = wayfSkippedRequestURL(from: requestURL) ?? requestURL
        guard NSWorkspace.shared.open(urlToOpen) else {
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
#elseif os(iOS)

import AuthenticationServices

class OAuthExternalUserAgent: NSObject, OIDExternalUserAgent {
    private var presentingViewController: ViewController
    private var isExternalUserAgentFlowInProgress = false
    private var wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?

    private var webAuthSession: ASWebAuthenticationSession?

    init(presentingViewController: AuthorizingViewController,
         wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?) {
        self.presentingViewController = presentingViewController
        self.wayfSkippingInfo = wayfSkippingInfo
    }

    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        if isExternalUserAgentFlowInProgress {
            return false
        }
        guard let requestURL = request.externalUserAgentRequestURL() else {
            return false
        }

        isExternalUserAgentFlowInProgress = true
        let urlToOpen = wayfSkippedRequestURL(from: requestURL) ?? requestURL
        let webAuthSession = ASWebAuthenticationSession(
            url: urlToOpen,
            callbackURLScheme: request.redirectScheme()) { [session, weak self] (url, error) in
                guard let self = self else { return }
                if let error = error {
                    session.failExternalUserAgentFlowWithError(
                        OIDErrorUtilities.error(
                            with: .browserOpenError,
                            underlyingError: error,
                            description: "ASWebAuthenticationSession failed"))
                    return
                }
                if let url = url {
                    session.resumeExternalUserAgentFlow(with: url)
                } else {
                    self.isExternalUserAgentFlowInProgress = false
                    session.failExternalUserAgentFlowWithError(
                        OIDErrorUtilities.error(
                            with: .userCanceledAuthorizationFlow,
                            underlyingError: nil,
                            description: nil))
                }
                self.webAuthSession = nil
        }

        if #available(iOS 13, *) {
            webAuthSession.presentationContextProvider = self
        }

        self.webAuthSession = webAuthSession
        return webAuthSession.start()
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        guard isExternalUserAgentFlowInProgress else {
            completion()
            return
        }
        self.webAuthSession?.cancel()
        isExternalUserAgentFlowInProgress = false
        completion()
    }
}

@available(iOS 13, *)
extension OAuthExternalUserAgent: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentingViewController.view.window!
    }
}
#endif

private extension OAuthExternalUserAgent {
    func wayfSkippedRequestURL(from requestURL: URL) -> URL? {
        if let wayfSkippingInfo = self.wayfSkippingInfo {
            if let percentEncodedOrgId = wayfSkippingInfo.orgId.xWWWFormURLEncoded(),
                let percentEncodedReturnTo = requestURL.absoluteString.xWWWFormURLEncoded() {
                let urlString = wayfSkippingInfo.authURLTemplate
                    .replacingOccurrences(of: "@ORG_ID@", with: percentEncodedOrgId)
                    .replacingOccurrences(of: "@RETURN_TO@", with: percentEncodedReturnTo)
                return URL(string: urlString)
            }
        }
        return nil
    }
}

private extension String {
    static var xWWWFormURLEncodedAllowedCharacters: CharacterSet = {
        // As per https://url.spec.whatwg.org/#application-x-www-form-urlencoded-percent-encode-set
        // the only characters that should be left unencoded are ASCII digits, ASCII letters and
        // the ASCII symbols *, -, . and _
        return CharacterSet(charactersIn: "*-._ ")
            .union(CharacterSet(charactersIn: "0"..."9"))
            .union(CharacterSet(charactersIn: "A"..."Z"))
            .union(CharacterSet(charactersIn: "a"..."z"))
    }()

    func xWWWFormURLEncoded() -> String? {
        return addingPercentEncoding(
            withAllowedCharacters: Self.xWWWFormURLEncodedAllowedCharacters)?
            .replacingOccurrences(of: " ", with: "+")
    }
}
