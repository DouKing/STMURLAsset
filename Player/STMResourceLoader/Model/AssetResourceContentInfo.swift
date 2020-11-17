//
//  AssetResourceContentInfo.swift
//  Player
//
//  Created by DouKing on 2020/11/16.
//

import Foundation

struct AssetResourceContentInfo: Codable {

	var contentLength: Int64
	var contentType: String
	var isByteRangeAccessSupported: Bool

	init(contentLength: Int64, contentType: String, isByteRangeAccessSupported: Bool) {
		self.contentLength = contentLength
		self.contentType = contentType
		self.isByteRangeAccessSupported = isByteRangeAccessSupported
	}

}
