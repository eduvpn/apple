//
//  FileService.swift
//  EduVPN-macOS
//

import Foundation

func filePathUrl(from url: URL) -> URL? {
    guard var fileUrl = applicationSupportDirectoryUrl() else { return nil }

    if let host = url.host {
        fileUrl.appendPathComponent(host)
    }

    if !url.path.isEmpty {
        fileUrl.appendPathComponent(url.path)
    }

    fileUrl = fileUrl.standardizedFileURL

    do {
        #if os(iOS)
        let attributes: [FileAttributeKey: Any]? = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        #elseif os(macOS)
        let attributes: [FileAttributeKey: Any]? = nil
        #endif

        try FileManager.default.createDirectory(at: fileUrl,
                                                withIntermediateDirectories: true,
                                                attributes: attributes)
    } catch {
        return nil
    }

    return fileUrl
}

func applicationSupportDirectoryUrl() -> URL? {
    guard var url = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true)
        else { return nil }
    
    #if os(macOS)
    guard let bundleID = Bundle.main.bundleIdentifier else {
        fatalError("missing bundle ID")
    }
    url.appendPathComponent(bundleID)
    do {
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
    } catch {
        return nil
    }
    #endif
    
    return url
}
