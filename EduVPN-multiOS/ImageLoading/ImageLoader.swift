//
//  ImageLoader.swift
//  EduVPN
//

import Foundation

#if os(macOS)
import AppKit
public typealias CrossPlatformImage = NSImage
public typealias CrossPlatformImageView = NSImageView
#else
import UIKit
public typealias CrossPlatformImage = UIImage
public typealias CrossPlatformImageView = UIImageView
#endif

public class ImageLoader {
    private static var dataTasks = [CrossPlatformImageView: URLSessionDataTask]()

    public static func loadImage(_ sourceUrl: URL, target: CrossPlatformImageView?) {
        guard Thread.isMainThread else {
            fatalError("ImageLoader should only be called on MainThread.")
        }
        guard let target = target else { return }

        let cache = URLCache.shared
        let request = URLRequest(url: sourceUrl)

        if let data = cache.cachedResponse(for: request)?.data, let image = CrossPlatformImage(data: data) {
            target.image = image
        } else {
            let dataTask = URLSession.shared.dataTask(with: sourceUrl, completionHandler: { (data, response, _) in
                if let data = data, let response = response, ((response as? HTTPURLResponse)?.statusCode ?? 500) < 300, let image = CrossPlatformImage(data: data) {
                    let cachedData = CachedURLResponse(response: response, data: data)
                    cache.storeCachedResponse(cachedData, for: request)
                    DispatchQueue.main.async {
                        if dataTasks.removeValue(forKey: target) != nil {
                            target.image = image
                        }
                    }
                }
            })
            dataTasks[target] = dataTask
            dataTask.resume()
        }
    }

    public static func cancelLoadImage(target: CrossPlatformImageView?) {
        guard Thread.isMainThread else {
            fatalError("ImageLoader should only be called on MainThread.")
        }
        guard let target = target else { return }
        dataTasks.removeValue(forKey: target)?.cancel()
    }
}
