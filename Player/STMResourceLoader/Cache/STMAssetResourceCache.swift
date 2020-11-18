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

private let kFragmentLength = 1024 * 512

public class STMAssetResourceCache {
    
    private(set) var configuration: STMAssetResourceConfiguration
    private let readFileHandle: FileHandle
    private let writeFileHandle: FileHandle

	private let readQueue: DispatchQueue = DispatchQueue(label: "com.douking.assetresource.cache.read")
	private let writeQueue: DispatchQueue = DispatchQueue(label: "com.douking.assetresource.cache.write")

    deinit {
        readFileHandle.closeFile()
        writeFileHandle.closeFile()
    }

	public init(url: URL) throws {
		let fileManager = FileManager.default
		let filePath = STMAssetResourceCacheManager.cachedFilePath(for: url)
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

    func actions(for range: NSRange) -> [STMAssetResourceFragment] {
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

    func set(info: STMAssetResourceContentInfo) {
		writeQueue.async {
			self.configuration.info = info
			self.writeFileHandle.truncateFile(atOffset: UInt64(info.contentLength))
			self.writeFileHandle.synchronizeFile()
		}
    }
    
    func save() {
		writeQueue.async {
			self.writeFileHandle.synchronizeFile()
			self.configuration.save()
		}
    }
}
