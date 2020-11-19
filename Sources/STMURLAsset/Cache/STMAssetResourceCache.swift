//
//  STMAssetResourceCache.swift
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

// 1kb
private let kFragmentLength = 1024 * 1
private let directory = NSTemporaryDirectory().appending("/STMVideoResource")

class STMAssetResourceCache {
    private let configuration: STMAssetResourceConfiguration
    private let readFileHandle: FileHandle
    private let writeFileHandle: FileHandle

	private let readQueue: DispatchQueue = DispatchQueue(label: "com.douking.assetresource.cache.read")
	private let writeQueue: DispatchQueue = DispatchQueue(label: "com.douking.assetresource.cache.write")

    deinit {
        readFileHandle.closeFile()
        writeFileHandle.closeFile()
    }

	init(url: URL) throws {
		let fileManager = FileManager.default
		let filePath = STMAssetResourceCache.cachedFilePath(for: url)
		let fileURL = URL(fileURLWithPath: filePath)
		let fileDirectory = (filePath as NSString).deletingLastPathComponent

		if !fileManager.fileExists(atPath: fileDirectory) {
			try fileManager.createDirectory(
				atPath: fileDirectory,
				withIntermediateDirectories: true,
				attributes: nil
			)
		}

		if !fileManager.fileExists(atPath: filePath) {
			fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
		}

		configuration = try STMAssetResourceConfiguration.configuration(for: filePath)
		readFileHandle = try FileHandle(forReadingFrom: fileURL)
		writeFileHandle = try FileHandle(forWritingTo: fileURL)
	}

	var assetResourceContentInfo: STMAssetResourceContentInfo? {
		set {
			guard let info = newValue else { return }
			writeQueue.async {
				self.configuration.info = info
				self.writeFileHandle.truncateFile(atOffset: UInt64(info.contentLength))
				self.writeFileHandle.synchronizeFile()
			}
		}
		get {
			return configuration.info
		}
	}

    func fragmens(for range: NSRange) -> [STMAssetResourceFragment] {
        guard range.location != NSNotFound else { return [] }
        
        var localFragments = [STMAssetResourceFragment]()
        
        for fragment in configuration.fragments {
            let intersection = NSIntersectionRange(range, fragment)

            guard intersection.length > 0 else {
                if fragment.location >= range.upperBound {
                    break
                } else {
                    continue
                }
            }

            let package = Double(intersection.length) / Double(kFragmentLength)
            let max = intersection.location + intersection.length

            for i in 0 ..< Int(package.rounded(.up)) {
                let offset = intersection.location + i * kFragmentLength
                let length = (offset + kFragmentLength) > max ? max - offset : kFragmentLength

                localFragments.append(STMAssetResourceFragment(
                    actionType: .local,
                    range: NSRange(location: offset, length: length)
                ))
            }
        }
        
        guard localFragments.count > 0 else {
			let ranges = subRanges(for: range)
			let fragments = ranges.map { STMAssetResourceFragment(actionType: .remote, range: $0) }
			if !fragments.isEmpty {
				return fragments
			}
            return [STMAssetResourceFragment(actionType: .remote, range: range)]
        }
        
        var localRemoteFragments = [STMAssetResourceFragment]()
        
        for (i, fragment) in localFragments.enumerated() {
            if i == 0 {
                if range.location < fragment.range.location {
                    localRemoteFragments.append(STMAssetResourceFragment(
                        actionType: .remote,
                        range: NSRange(
                            location: range.location,
                            length: fragment.range.location - range.location
                        )
                    ))
                }
                localRemoteFragments.append(fragment)
            } else if let lastOffset = localRemoteFragments.last?.range.upperBound {
                if lastOffset < fragment.range.location {
                    localRemoteFragments.append(STMAssetResourceFragment(
                        actionType: .remote,
                        range: NSRange(
                            location: lastOffset,
                            length: fragment.range.location - lastOffset
                        )
                    ))
                }
                localRemoteFragments.append(fragment)
            }
            
            if i == localFragments.count - 1, fragment.range.upperBound < range.upperBound {
                localRemoteFragments.append(STMAssetResourceFragment(
                    actionType: .remote,
                    range: NSRange(
                        location: fragment.range.upperBound,
                        length: range.upperBound - fragment.range.upperBound
                    )
                ))
            }
        }
        
        return localRemoteFragments
    }
    
    func cache(data: Data, for range: NSRange) {
		writeQueue.async {
			self.writeFileHandle.seek(toFileOffset: UInt64(range.location))
			self.writeFileHandle.write(data)
			self.configuration.add(fragment: range)
		}
    }
    
    func cachedData(for range: NSRange) -> Data {
		readQueue.sync {
			self.readFileHandle.seek(toFileOffset: UInt64(range.location))
			return self.readFileHandle.readData(ofLength: range.length)
		}
    }

    func save() {
		writeQueue.async {
			self.writeFileHandle.synchronizeFile()
			self.configuration.save()
		}
    }

	private func subRanges(for range: NSRange) -> [NSRange] {
		let maxLocation = range.location + range.length
		var ranges: [NSRange] = []

		var currentRange = range
		while currentRange.location < maxLocation {
			let location = currentRange.location
			if currentRange.length >= kFragmentLength * 2 {
				let length = kFragmentLength
				let fragment = NSRange(location: location, length: length)
				ranges.append(fragment)
				currentRange = NSRange(location: location + length, length: currentRange.length - length)
			} else {
				ranges.append(currentRange)
				break
			}
		}

		return ranges
	}

	static func cachedSize() -> UInt {
		let fileManager = FileManager.default
		let resourceKeys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]

		let fileContents = { () -> [URL] in
			if let contens = try? fileManager
				.contentsOfDirectory(
					at: URL(fileURLWithPath: directory),
					includingPropertiesForKeys: Array(resourceKeys),
					options: .skipsHiddenFiles
				) { return contens }
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

	static func cleanAllCache() throws {
		let fileManager = FileManager.default
		let fileContents = try fileManager.contentsOfDirectory(atPath: directory)

		for fileContent in fileContents {
			let filePath = directory.appending("/\(fileContent)")
			try fileManager.removeItem(atPath: filePath)
		}
	}

	private static func cachedFilePath(for url: URL) -> String {
		var result = (directory as NSString).appendingPathComponent(url.absoluteString.md5)
		result = (result as NSString).appendingPathExtension(url.pathExtension)!
		return result
	}

	private static func cachedConfiguration(for url: URL) throws -> STMAssetResourceConfiguration {
		return try STMAssetResourceConfiguration.configuration(for: cachedFilePath(for: url))
	}
}
