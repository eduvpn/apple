//
//  CertificateModel.swift
//  eduVPN
//
//  Created by Jeroen Leenarts on 08-01-18.
//  Copyright © 2018 SURFNet. All rights reserved.
//

import Foundation
import ASN1Decoder

struct CertificateModel: Codable {
    
    var certificateString: String
    var privateKeyString: String
    var x509Certificate: X509Certificate? {
        return try? X509Certificate(data: certificateString.data(using: .utf8)!)
    }

    var uniqueIdentifier: String? {
        return x509Certificate?.signature?.base64EncodedString()
    }
}

extension CertificateModel {
    
    enum CertificateModelKeys: String, CodingKey {
        case createKeypair = "create_keypair"
        case data
        case certificate
        case privateKey = "private_key"
//        case okKey = "ok"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CertificateModelKeys.self)
        var createKeypairContainer = container.nestedContainer(keyedBy: CertificateModelKeys.self, forKey: .createKeypair)
        var dataContainer = createKeypairContainer.nestedContainer(keyedBy: CertificateModelKeys.self, forKey: .data)
        try dataContainer.encode(certificateString, forKey: .certificate)
        try dataContainer.encode(privateKeyString, forKey: .privateKey)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CertificateModelKeys.self)
        let createKeypairResponse = try container.nestedContainer(keyedBy: CertificateModelKeys.self, forKey: .createKeypair)
//        let okResult = try createKeypairResponse.decode(Bool.self, forKey: .okKey)
        let data = try createKeypairResponse.nestedContainer(keyedBy: CertificateModelKeys.self, forKey: .data)
        certificateString = try data.decode(String.self, forKey: .certificate)
        privateKeyString = try data.decode(String.self, forKey: .privateKey)
    }
}
