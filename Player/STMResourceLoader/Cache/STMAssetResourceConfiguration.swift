//
//  STMAssetResourceConfiguration.swift
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

struct STMAssetResourceConfiguration: Codable {
	private init(filePath: String) {
		self.filePath = filePath
	}

	static func configuration(for assetResourcePath: String) throws -> STMAssetResourceConfiguration {
		let filePath = configurationFilePath(for: assetResourcePath)

		guard FileManager.default.fileExists(atPath: filePath),
			  let data = FileManager.default.contents(atPath: filePath)
		else {
			return STMAssetResourceConfiguration(filePath: filePath)
		}

		var configuration = try JSONDecoder().decode(STMAssetResourceConfiguration.self, from: data)
		configuration.filePath = filePath

		return configuration
	}

	static func configurationFilePath(for assetResourcePath: String) -> String {
		return (assetResourcePath as NSString).appendingPathExtension("stm")!
	}

	mutating func add(fragment: NSRange) {
		guard fragment.location != NSNotFound, fragment.length > 0 else { return }

		if fragments.count == 0 {
			fragments.append(fragment)
			return
		}

		var indexSet = IndexSet()

		for (i, range) in fragments.enumerated() {
			if fragment.upperBound <= range.location {
				if indexSet.count == 0 { indexSet.insert(i) }
				break
			} else if fragment.location <= range.upperBound && fragment.upperBound > range.location {
				indexSet.insert(i)
			} else if fragment.location >= range.upperBound {
				if i == fragments.count - 1 { indexSet.insert(i) }
			}
		}

		guard let firstIndex = indexSet.first, let lastIndex = indexSet.last else { return }

		if indexSet.count == 1 {
			var range1 = fragments[firstIndex]
			range1.length += 1

			var range2 = fragment
			range2.length += 1

			let intersection = NSIntersectionRange(range1, range2)

			if intersection.length == 0 {
				if fragment.location < fragments[firstIndex].location {
					fragments.insert(fragment, at: firstIndex)
				} else {
					fragments.insert(fragment, at: lastIndex + 1)
				}
				return
			}
		}

		let location = min(fragments[firstIndex].location, fragment.location)
		let upperBound = max(fragments[lastIndex].upperBound, fragment.upperBound)
		let combine = NSRange(location: location, length: upperBound - location)

		fragments = fragments.enumerated().compactMap { indexSet.contains($0.0) ? nil : $0.1 }
		fragments.insert(combine, at: firstIndex)
	}

	func save() {
		do {
			if FileManager.default.fileExists(atPath: filePath) {
				try FileManager.default.removeItem(atPath: filePath)
			}

			if !FileManager.default.createFile(
				atPath: filePath,
				contents: try JSONEncoder().encode(self),
				attributes: nil
			) {
				throw NSError(
					domain: "com.douking.assetresource.cache",
					code: -1,
					userInfo: [NSLocalizedDescriptionKey: "Failed to create file"]
				)
			}
		} catch {
			//VideoLoadManager.shared.reportError?(error)
		}
	}

	//--------------------------------------------------------------------------------
	// MARK: - Property
	//--------------------------------------------------------------------------------

	private(set) var fragments: [NSRange] = []
	private var filePath: String

	var info: STMAssetResourceContentInfo?

	var downloadedByteCount: Int {
		return fragments.reduce(0) { $0 + $1.length }
	}

	var progress: Double {
		guard let info = info, info.contentLength > 0 else { return 0 }
		return Double(downloadedByteCount) / Double(info.contentLength)
	}

}
