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
    case dataCouldNotBeVerified(url: URL)
    case dataNotFoundInCache
    case dataNotFoundInAppBundle
    case versionNumberNotFound(url: URL)
    case versionNumberDecreased(url: URL, previousVersion: Int, newVersion: Int)
    case versionNumberUnchangedWithContentChange(url: URL, version: Int)
}

extension DiscoveryDataFetcherError: AppError {
    var summary: String {
        switch self {
        case .dataCouldNotBeVerified:
            return "Discovery data could not be verified"
        case .dataNotFoundInCache:
            return "Discovery data not found in cache"
        case .dataNotFoundInAppBundle:
            return "Discovery data not found in app bundle"
        case .versionNumberNotFound:
            return "Discovery data doesn't contain version number"
        case .versionNumberDecreased:
            return "Discovery data was not updated because the version number has decreased"
        case .versionNumberUnchangedWithContentChange:
            return "Discovery data was not updated because the version number remains unchanged even when content has changed"
        }
    }
    var detail: String {
        switch self {
        case .dataCouldNotBeVerified(let url):
            return "URL: \(url)"
        case .dataNotFoundInCache, .dataNotFoundInAppBundle:
            return ""
        case .versionNumberNotFound(let url):
            return "URL: \(url)"
        case .versionNumberDecreased(let url, let previousVersion, let newVersion):
            return """
            URL: \(url)
            Previous version: \(previousVersion)
            New version: \(newVersion)
            """
        case .versionNumberUnchangedWithContentChange(let url, let version):
            return """
            URL: \(url)
            Version: \(version)
            """
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

    struct CacheContents {
        let dataURL: URL
        let dataResponse: CachedURLResponse
        let signatureURL: URL
        let signatureResponse: CachedURLResponse

        func store(to cache: URLCache) throws {
            for (url, response) in [(dataURL, dataResponse), (signatureURL, signatureResponse)] {
                let request = try URLRequest(url: url, method: .get)
                cache.storeCachedResponse(response, for: request)
            }
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
                let (data, _) = try getFromDiskCache(
                    dataURL: dataURL, signatureURL: signatureURL,
                    publicKeys: publicKeys)
                seal.fulfill(data)
            }
        case .server:
            return getFromRemoteServerWithRollbackPrevention(
                dataURL: dataURL,
                signatureURL: signatureURL,
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

    private static func getFromDiskCache(dataURL: URL, signatureURL: URL, publicKeys: [Data]) throws -> (Data, CacheContents) {
        guard let dataResponse = diskCache.cachedResponse(for: URLRequest(url: dataURL)),
              let signatureResponse = diskCache.cachedResponse(for: URLRequest(url: signatureURL)) else {
            throw DiscoveryDataFetcherError.dataNotFoundInCache
        }
        let data = try verify(data: dataResponse.data,
                          signature: signatureResponse.data,
                          publicKeys: publicKeys,
                          dataURL: dataURL)
        let cacheContents = CacheContents(
            dataURL: dataURL,
            dataResponse: dataResponse,
            signatureURL: signatureURL,
            signatureResponse: signatureResponse)
        return (data, cacheContents)
    }

    private static func getFromRemoteServer(dataURL: URL, signatureURL: URL, publicKeys: [Data]) -> Promise<Data> {
        let dataProvider = MoyaProvider<Target>(session: cachedSession)
        let dataPromise = dataProvider.request(target: Target(dataURL))

        let signatureProvider = MoyaProvider<Target>(session: cachedSession)
        let signaturePromise = signatureProvider.request(target: Target(signatureURL))

        return when(fulfilled: dataPromise, signaturePromise)
            .map { dataResponse, signatureResponse in
                return try verify(data: dataResponse.data, signature: signatureResponse.data,
                                  publicKeys: publicKeys, dataURL: dataURL)
            }
    }

    private static func getFromRemoteServerWithRollbackPrevention(
        dataURL: URL, signatureURL: URL, publicKeys: [Data]) -> Promise<Data> {
        let (previousData, previousVersion, cacheContents): (Data?, Int?, CacheContents?) = {
            if let (data, cacheContents) = try? getFromDiskCache(
                dataURL: dataURL, signatureURL: signatureURL,
                publicKeys: publicKeys) {
                let version = versionValue(from: data)
                return (data, version, cacheContents)
            } else if let data = try? getFromAppBundle(dataURL: dataURL) {
                let version = versionValue(from: data)
                return (data, version, nil)
            } else {
                return (nil, nil, nil)
            }
        }()
        return firstly {
            getFromRemoteServer(
                dataURL: dataURL, signatureURL: signatureURL,
                publicKeys: publicKeys)
        }.map { data in
            if previousData == data {
                // Data hasn't changed
                return data
            }
            if let newVersion = versionValue(from: data) {
                if let previousVersion = previousVersion {
                    if newVersion > previousVersion {
                        // Data has changed and version number has gone up
                        return data
                    } else if newVersion < previousVersion {
                        try? cacheContents?.store(to: diskCache)
                        throw DiscoveryDataFetcherError.versionNumberDecreased(
                            url: dataURL,
                            previousVersion: previousVersion,
                            newVersion: newVersion)
                    } else {
                        try? cacheContents?.store(to: diskCache)
                        throw DiscoveryDataFetcherError.versionNumberUnchangedWithContentChange(
                            url: dataURL,
                            version: previousVersion)
                    }
                } else {
                    // No previous version. Can't really happen.
                    return data
                }
            } else {
                throw DiscoveryDataFetcherError.versionNumberNotFound(url: dataURL)
            }
        }
    }

    private static func versionValue(from data: Data) -> Int? {
        guard let versionable = try? JSONDecoder().decode(VersionableDiscoveryData.self, from: data) else {
            return nil
        }
        return versionable.version
    }

    private static func verify(data: Data, signature: Data, publicKeys: [Data], dataURL: URL) throws -> Data {
        let signature = try SignatureHelper.minisignSignatureFromFile(data: signature)
        for publicKey in publicKeys {
            let isValid = SignatureHelper.isSignatureValid(
                data: data, signatureWithMetadata: signature,
                publicKeyWithMetadata: publicKey)
            if isValid {
                return data
            }
        }
        throw DiscoveryDataFetcherError.dataCouldNotBeVerified(url: dataURL)
    }
}

private struct VersionableDiscoveryData: Decodable {
    let version: Int

    enum CodingKeys: String, CodingKey {
        case version = "v"
    }
}
