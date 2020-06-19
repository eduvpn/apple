//
//  DiscoveryDataFetcher.swift
//  EduVPN
//
//  Fetches server_list.json or organization_list.json and verifies the signature
//

import Foundation
import Moya
import PromiseKit

enum DiscoveryDataFetcherError: LocalizedError {
    case dataCouldNotBeVerified

    var errorDescription: String? {
        switch self {
        case .dataCouldNotBeVerified:
            return NSLocalizedString("Discovery data could not be verified", comment: "")
        }
    }
}

struct DiscoveryDataFetcher {

    struct Target: TargetType, AcceptJson, SimpleGettable {
        var baseURL: URL
        init(_ url: URL) {
            baseURL = url
        }
    }

    static var diskCache: URLCache {
        let cacheURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appendingPathComponent("DiscoveryData")
        let cacheSize = 10 * 1024 * 1024 // 10 MB in bytes
        return URLCache(memoryCapacity: cacheSize, diskCapacity: cacheSize, diskPath: cacheURL?.path)
    }

    static var cachedSession: Moya.Session {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = diskCache
        return Session(configuration: configuration, startRequestsImmediately: false)
    }

    static func fetch(dataURL: URL, signatureURL: URL, publicKeys: [Data]) -> Promise<Data> {
        let dataProvider = MoyaProvider<Target>(session: cachedSession)
        let dataPromise = dataProvider.request(target: Target(dataURL))

        let signatureProvider = MoyaProvider<Target>(session: cachedSession)
        let signaturePromise = signatureProvider.request(target: Target(signatureURL))

        return when(fulfilled: dataPromise, signaturePromise)
            .map { dataResponse, signatureResponse in
                return try verify(data: dataResponse.data, signature: signatureResponse.data,
                                  publicKeys: publicKeys)
            }
    }

    static func cachedData(dataURL: URL, signatureURL: URL, publicKeys: [Data]) -> Data? {
        guard let dataResponse = diskCache.cachedResponse(for: URLRequest(url: dataURL)),
            let signatureResponse = diskCache.cachedResponse(for: URLRequest(url: signatureURL)) else {
                return nil
        }
        return try? verify(data: dataResponse.data, signature: signatureResponse.data,
                           publicKeys: publicKeys)
    }

    private static func verify(data: Data, signature: Data, publicKeys: [Data]) throws -> Data {
        let signature = try SignatureHelper.minisignSignatureFromFile(data: signature)
        for publicKey in publicKeys {
            let isValid = SignatureHelper.isSignatureValid(
                data: data, signatureWithMetadata: signature,
                publicKeyWithMetadata: publicKey)
            if isValid {
                return data
            }
        }
        throw DiscoveryDataFetcherError.dataCouldNotBeVerified
    }
}
