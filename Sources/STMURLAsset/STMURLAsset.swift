//
//  STMURLAsset.swift
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

import AVFoundation

public class STMURLAsset: AVURLAsset {

	private var assetLoaderManager: STMAssetResourceLoaderManager?

	deinit {
		assetLoaderManager?.cancel()
	}

	public override init(url: URL, options: [String : Any]? = nil) {
		guard !url.isFileURL else {
			super.init(url: url, options: options)
			return
		}

		guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			super.init(url: url, options: options)
			return
		}

		urlComponents.scheme = STMAssetResourceLoaderManager.scheme
		guard let assetURL = urlComponents.url else {
			super.init(url: url, options: options)
			return
		}

		super.init(url: assetURL, options: options)
		assetLoaderManager = try? STMAssetResourceLoaderManager(with: url)
		resourceLoader.setDelegate(assetLoaderManager, queue: .main)
	}

	public func preloadAsynchronously(_ completion: ((AVKeyValueStatus, Error?) -> Void)? = nil) {
		loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
			guard let self = self else {
				completion?(.unknown, nil)
				return
			}
			var error: NSError? = nil
			let status = self.statusOfValue(forKey: "playable", error: &error)
			completion?(status, error)
		}
	}
    
    @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
    public func preload() async throws -> AVAsyncProperty<STMURLAsset, Bool>.Status {
        _ = try await load(.isPlayable)
        let status = status(of: .isPlayable)
        return status
    }

	// MARK: setter & getter

	public weak var resourceLoaderDelegate: STMAssetResourceLoaderManagerDelegate? {
		get {
			assetLoaderManager?.delegate
		}
		set {
			assetLoaderManager?.delegate = newValue
		}
	}
}
