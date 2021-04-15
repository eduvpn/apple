//
//  DiscoveryDataFetcher.swift
//  EduVPN
//
//  Fetches server_list.json or organization_list.json and verifies the signature
//

import Foundation
import Moya
import PromiseKit

enum DiscoveryDataFetcherError: Error {
    case dataCouldNotBeVerified
    case dataNotFoundInCache
    case dataNotFoundInAppBundle
}

extension DiscoveryDataFetcherError: AppError {
    var summary: String {
        switch self {
        case .dataCouldNotBeVerified: return "Discovery data could not be verified"
        case .dataNotFoundInCache: return "Discovery data not found in cache"
        case .dataNotFoundInAppBundle: return "Discovery data not found in app bundle"
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

    enum DataOrigin {
        case appBundle // Get the data from the JSON file contained in the app bundle
        case cache // Get the data from the web cache
        case server // Download the data afresh from the discovery server
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

    static func get(from origin: DataOrigin, dataURL: URL, signatureURL: URL,
                    publicKeys: [Data]) -> Promise<Data> {
        switch origin {
        case .appBundle:
            return Promise { seal in
                let data = try getFromAppBundle(dataURL: dataURL)
                seal.fulfill(data)
            }
        case .cache:
            return Promise { seal in
                let data = try getFromDiskCache(
                    dataURL: dataURL, signatureURL: signatureURL,
                    publicKeys: publicKeys)
                seal.fulfill(data)
            }
        case .server:
            return getFromRemoteServer(
                dataURL: dataURL, signatureURL: signatureURL,
                publicKeys: publicKeys)
        }
    }

    private static func getFromAppBundle(dataURL: URL) throws -> Data {
        let splitLastPathComponent = dataURL.lastPathComponent.split(separator: ".")
        guard splitLastPathComponent.count == 2 else {
            throw DiscoveryDataFetcherError.dataNotFoundInAppBundle
        }
        let fileName = String(splitLastPathComponent[0])
        let fileExtension = String(splitLastPathComponent[1])
        guard let includedServerListURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            throw DiscoveryDataFetcherError.dataNotFoundInAppBundle
        }
        return try Data(contentsOf: includedServerListURL)
    }

    private static func getFromDiskCache(dataURL: URL, signatureURL: URL, publicKeys: [Data]) throws -> Data {
        guard let dataResponse = diskCache.cachedResponse(for: URLRequest(url: dataURL)),
              let signatureResponse = diskCache.cachedResponse(for: URLRequest(url: signatureURL)) else {
            throw DiscoveryDataFetcherError.dataNotFoundInCache
        }
        return try verify(data: dataResponse.data,
                          signature: signatureResponse.data,
                          publicKeys: publicKeys)
    }

    private static func getFromRemoteServer(dataURL: URL, signatureURL: URL, publicKeys: [Data]) -> Promise<Data> {
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

    private static func versionValue(from data: Data) -> Int? {
        guard let versionable = try? JSONDecoder().decode(VersionableDiscoveryData.self, from: data) else {
            return nil
        }
        return versionable.version
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

fileprivate struct VersionableDiscoveryData: Decodable {
    let version: Int

    enum CodingKeys: String, CodingKey {
        case version = "v"
    }
}
