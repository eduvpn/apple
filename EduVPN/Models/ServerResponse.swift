//
//  ServerResponse.swift
//  EduVPN
//

import Foundation

protocol ServerResponse {
    associatedtype DataType
    var data: DataType { get }
    init(data: Data) throws
}

struct Profile: Codable {
    let displayName: LanguageMappedString
    let profileId: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case profileId = "profile_id"
    }
}

// Responses for APIv2

protocol ServerResponseAPIv2: ServerResponse {
}

// Parse response to a /profile_list request
//
// Example response:
// {
//     "profile_list": {
//         "data": [
//             {
//                 "display_name": "Internet Access",
//                 "profile_id": "internet",
//                 "default_gateway": true,
//             }
//         ],
//         "ok": true
//     }
// }

struct ProfileListResponsev2: ServerResponseAPIv2, Decodable {
    let data: [Profile]

    enum TopLevelKeys: String, CodingKey {
        case profile_list // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelKeys.self)
        let dataContainer = try topLevelContainer.nestedContainer(
            keyedBy: SecondLevelKeys.self, forKey: .profile_list)
        self.data = try dataContainer.decode([Profile].self, forKey: .data)
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(ProfileListResponsev2.self, from: data)
    }
}

// Parse response to a /create_keypair request
//
// Example response:
// {
//     "create_keypair": {
//         "data": {
//             "certificate": "-----BEGIN CERTIFICATE----- ... -----END CERTIFICATE-----",
//             "private_key": "-----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----"
//         },
//         "ok": true
//     }
// }

struct CreateKeyPairResponse: ServerResponseAPIv2, Decodable {

    struct KeyPair: Codable {
        let certificate: String
        let privateKey: String

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case certificate
            case privateKey = "private_key"
        }
    }

    let data: KeyPair

    enum TopLevelKeys: String, CodingKey {
        case create_keypair // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelKeys.self)
        let dataContainer = try topLevelContainer.nestedContainer(
            keyedBy: SecondLevelKeys.self, forKey: .create_keypair)
        self.data = try dataContainer.decode(KeyPair.self, forKey: .data)
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(CreateKeyPairResponse.self, from: data)
    }
}

// The response to a /profile_config request is raw data

struct ProfileConfigResponse: ServerResponseAPIv2 {
    let data: Data
    init(data: Data) {
        self.data = data
    }
}

// Parse error response to a /profile_config request
//
// Example error response:
// {
//     "profile_config": {
//         "error": "profile not available or no permission"
//         "ok": false,
//     }
// }

struct ProfileConfigErrorResponsev2: Decodable {

    let errorMessage: String

    enum TopLevelKeys: String, CodingKey {
        case profile_config // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelKeys.self)
        let dataContainer = try topLevelContainer.nestedContainer(
            keyedBy: SecondLevelKeys.self, forKey: .profile_config)
        self.errorMessage = try dataContainer.decode(String.self, forKey: .error)
    }
}

// Parse response to a /check_certificate request
//
// Example response:
// {
//     "check_certificate": {
//         "data": {
//             "is_valid": true
//         },
//         "ok": true
//     }
// }

struct CheckCertificateResponse: ServerResponseAPIv2, Decodable {
    struct CertificateValidity: Decodable {
        let isValid: Bool

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case isValid = "is_valid"
        }
    }

    let data: CertificateValidity

    enum TopLevelKeys: String, CodingKey {
        case check_certificate // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelKeys.self)
        let dataContainer = try topLevelContainer.nestedContainer(
            keyedBy: SecondLevelKeys.self, forKey: .check_certificate)
        self.data = try dataContainer.decode(CertificateValidity.self, forKey: .data)
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(CheckCertificateResponse.self, from: data)
    }
}

private enum SecondLevelKeys: String, CodingKey {
    case data
    case error
}

// Responses for APIv3

protocol ServerResponseAPIv3: ServerResponse {
}

// Parse response to a /info request
//
// Example response:
// {
//     "info": {
//         "profile_list": [
//             {
//                 "display_name": {
//                     "en": "Employees",
//                     "nl": "Medewerkers"
//                 },
//                 "profile_id": "employees"
//             },
//             {
//                 "display_name": "Administrators",
//                 "profile_id": "admins"
//             }
//         ]
//     }
// }

struct InfoResponse: ServerResponseAPIv3, Decodable {
    let data: [Profile]

    enum TopLevelKeys: String, CodingKey {
        case info
    }

    enum SecondLevelKeys: String, CodingKey {
        case profile_list // swiftlint:disable:this identifier_name
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelKeys.self)
        let profileListContainer = try topLevelContainer.nestedContainer(
            keyedBy: SecondLevelKeys.self, forKey: .info)
        self.data = try profileListContainer.decode([Profile].self, forKey: .profile_list)
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(InfoResponse.self, from: data)
    }
}

// The response to a /connect request is raw data

struct ConnectResponse: ServerResponseAPIv3 {
    let data: Data
    init(data: Data) {
        self.data = data
    }
}

// Parse error response to a /connect request
//
// Example error response:
// {
//     "error": "invalid \"profile_id\""
// }

struct ProfileConfigErrorResponse: Decodable {

    let errorMessage: String

    enum TopLevelKeys: String, CodingKey {
        case error
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelKeys.self)
        self.errorMessage = try topLevelContainer.decode(String.self, forKey: .error)
    }
}
