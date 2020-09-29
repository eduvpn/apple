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
class OAuthExternalUserAgent: NSObject, OIDExternalUserAgent {
    private var isExternalUserAgentFlowInProgress = false
    private var wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?

    init(presentingViewController: AuthorizingViewController,
         wayfSkippingInfo: ServerAuthService.WAYFSkippingInfo?) {
        self.wayfSkippingInfo = wayfSkippingInfo
    }

    func present(_ request: OIDExternalUserAgentRequest, session: OIDExternalUserAgentSession) -> Bool {
        return false
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        isExternalUserAgentFlowInProgress = false
        completion()
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
