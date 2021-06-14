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

struct ProfileListResponse: ServerResponse, Decodable {
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
        self = try JSONDecoder().decode(ProfileListResponse.self, from: data)
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

struct CreateKeyPairResponse: ServerResponse, Decodable {

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

struct ProfileConfigResponse: ServerResponse {
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

struct ProfileConfigErrorResponse: Decodable {

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

struct CheckCertificateResponse: ServerResponse, Decodable {
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
