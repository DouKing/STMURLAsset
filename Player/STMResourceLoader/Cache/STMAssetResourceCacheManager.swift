//
//  STMAssetResourceCacheManager.swift
//
//  Copyright © 2020-2024 DouKing. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

private let directory = NSTemporaryDirectory().appending("/STMVideoResource")

enum STMAssetResourceCacheManager {
	static func cachedFilePath(for url: URL) -> String {
		var result = (directory as NSString).appendingPathComponent(url.absoluteString.md5)
		result = (result as NSString).appendingPathExtension(url.pathExtension)!
		return result
	}

	static func cachedConfiguration(for url: URL) throws -> STMAssetResourceConfiguration {
		return try STMAssetResourceConfiguration.configuration(for: cachedFilePath(for: url))
	}

	public static func calculateCachedSize() -> UInt {
		let fileManager = FileManager.default
		let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]

		let fileContents = { () -> [URL] in
			if let contens = try? fileManager
				.contentsOfDirectory(
					at: URL(fileURLWithPath: directory),
					includingPropertiesForKeys: Array(resourceKeys),
					options: .skipsHiddenFiles
				) {
				return contens
			}
			return []
		}()

		return fileContents.reduce(0) { size, fileContent in
			guard let resourceValues = try? fileContent.resourceValues(forKeys: resourceKeys),
				  resourceValues.isDirectory != true,
				  let fileSize = resourceValues.totalFileAllocatedSize
			else { return size }

			return size + UInt(fileSize)
		}
	}

	public static func cleanAllCache() throws {
		let fileManager = FileManager.default
		let fileContents = try fileManager.contentsOfDirectory(atPath: directory)

		for fileContent in fileContents {
			let filePath = directory.appending("/\(fileContent)")
			try fileManager.removeItem(atPath: filePath)
		}
	}
}
