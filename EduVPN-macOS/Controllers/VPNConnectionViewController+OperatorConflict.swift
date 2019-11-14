//
//  VPNConnectionViewController+OperatorConflict.swift
//  EduVPN-macOS
//
//  Created by Jeroen Leenarts on 14/11/2019.
//  Copyright © 2019 SURFNet. All rights reserved.
//

import Foundation
import Kingfisher

extension VPNConnectionViewController {
    func updateImage(with url: URL) {
        providerImage.kf.setImage(with: url)
    }

    func cancelImageDownload() {
        providerImage.kf.cancelDownloadTask()
    }
}
