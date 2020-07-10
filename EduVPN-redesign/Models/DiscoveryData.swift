//
//  DiscoveryData.swift
//  EduVPN
//

// Models the data extracted from server_list.json and organization_list.json

struct DiscoveryData {
    typealias BaseURLString = String
    typealias OrgId = String

    struct InstituteAccessServer {
        let baseURLString: BaseURLString
        let displayName: LanguageMappedString
        let supportContact: [String]
    }

    struct SecureInternetServer {
        let baseURLString: BaseURLString
        let countryCode: String
        let supportContact: [String]
    }

    struct Organization {
        let orgId: OrgId
        let displayName: LanguageMappedString
        let keywordList: LanguageMappedString?
        let secureInternetHome: BaseURLString
    }

    struct Servers {
        let instituteAccessServers: [InstituteAccessServer]
        let secureInternetServersMap: [BaseURLString: SecureInternetServer]
    }

    struct Organizations {
        let organizations: [Organization]
    }
}

extension DiscoveryData.Organization: Decodable {
    enum CodingKeys: String, CodingKey {
        case orgId = "org_id"
        case displayName = "display_name"
        case keywordList = "keyword_list"
        case secureInternetHome = "secure_internet_home"
    }
}

extension DiscoveryData.Servers: Decodable {
    enum ServerListTopLevelKeys: String, CodingKey {
        case server_list // swiftlint:disable:this identifier_name
    }

    private struct ServerEntry: Decodable {
        let serverType: String
        let baseURLString: String
        let displayName: LanguageMappedString?
        let countryCode: String?
        let supportContact: [String]?

        enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case serverType = "server_type"
            case baseURLString = "base_url"
            case displayName = "display_name"
            case countryCode = "country_code"
            case supportContact = "support_contact"
        }
    }

    init(from decoder: Decoder) throws {
        let listContainer = try decoder.container(keyedBy: ServerListTopLevelKeys.self)
        let list = try listContainer.decode([ServerEntry].self, forKey: .server_list)
        var instituteAccessServers: [DiscoveryData.InstituteAccessServer] = []
        var secureInternetServersMap: [DiscoveryData.BaseURLString: DiscoveryData.SecureInternetServer] = [:]
        for serverEntry in list {
            let baseURLString = serverEntry.baseURLString
            let supportContact = serverEntry.supportContact ?? []
            switch serverEntry.serverType {
            case "institute_access":
                if let displayName = serverEntry.displayName {
                    instituteAccessServers.append(DiscoveryData.InstituteAccessServer(
                        baseURLString: baseURLString, displayName: displayName,
                        supportContact: supportContact))
                }
            case "secure_internet":
                if let countryCode = serverEntry.countryCode {
                    secureInternetServersMap[baseURLString] = DiscoveryData.SecureInternetServer(
                        baseURLString: baseURLString, countryCode: countryCode,
                        supportContact: supportContact)
                }
            default:
                break
            }
        }
        self.instituteAccessServers = instituteAccessServers
        self.secureInternetServersMap = secureInternetServersMap
    }
}

extension DiscoveryData.Organizations: Decodable {
    enum OrgListTopLevelKeys: String, CodingKey {
        case organization_list // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let listContainer = try decoder.container(keyedBy: OrgListTopLevelKeys.self)
        let list = try listContainer.decode([DiscoveryData.Organization].self, forKey: .organization_list)
        self.organizations = list
    }
}
