//
//  STMAssetResourceLoaderManager.swift
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

import UIKit
import AVFoundation
import CoreServices

public class STMAssetResourceLoaderManager: NSObject {
	static let scheme = "stmresourceloader"

	public let originalURL: URL
	public weak var delegate: STMAssetResourceLoaderManagerDelegate?

	private let originalScheme: String?
	private var pendingRequests: [AVAssetResourceLoadingRequest] = []
    private var loaders: [STMAssetResourceLoader] = []
	private let cacheHandler: STMAssetResourceCache

	public init(with url: URL) throws {
		self.originalURL = url
		self.originalScheme = url.scheme
		self.cacheHandler = try STMAssetResourceCache.instance(forURL: url)
		super.init()
	}
    
    func cancel() {
        for loader in loaders {
            loader.cancel()
        }
    }
}

//--------------------------------------------------------------------------------
// MARK: - AVAssetResourceLoaderDelegate
//--------------------------------------------------------------------------------

extension STMAssetResourceLoaderManager: AVAssetResourceLoaderDelegate {
	public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
							   shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
		guard let loadingURL = loadingRequest.request.url,
			  let scheme = loadingURL.scheme,
			  scheme == STMAssetResourceLoaderManager.scheme
		else { return false }

		if let _ = pendingRequests.first(where: { (obj: AVAssetResourceLoadingRequest) -> Bool in
			guard obj.request == loadingRequest.request else { return false }
			guard (obj.dataRequest?.requestedOffset ?? 0) == (loadingRequest.dataRequest?.requestedOffset ?? 0) else { return false }
			guard (obj.dataRequest?.requestedLength ?? 0) == (loadingRequest.dataRequest?.requestedLength ?? 0) else { return false }
			return true
		}) {
			return false
		}

		if loadingRequest.contentInformationRequest == nil && loadingRequest.dataRequest == nil {
			return false
		}

		guard let requestLength = loadingRequest.dataRequest?.requestedLength, requestLength > 0 else {
			return false
		}

        let realURL = url(for: loadingRequest)
		pendingRequests.append(loadingRequest)
		let loader = STMAssetResourceLoader(with: realURL, loadingRequest: loadingRequest, cacheHandler: cacheHandler)
		loader.delegate = self
        loader.startLoad()
        loaders.append(loader)

		return true
	}

	public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
		guard let index = pendingRequests.firstIndex(of: loadingRequest) else { return }
        loaders[index].cancel()
	}
}

//--------------------------------------------------------------------------------
// MARK: - Helper
//--------------------------------------------------------------------------------

extension STMAssetResourceLoaderManager {
	private func url(for loadingRequest: AVAssetResourceLoadingRequest) -> URL {
		guard let loadingURL = loadingRequest.request.url else { return originalURL }
		guard var urlComponents = URLComponents(url: loadingURL, resolvingAgainstBaseURL: false)
		else { return originalURL }

		urlComponents.scheme = originalScheme
		return urlComponents.url ?? originalURL
	}
}

//--------------------------------------------------------------------------------
// MARK: - STMAssetResourceLoaderDelegate
//--------------------------------------------------------------------------------

extension STMAssetResourceLoaderManager: STMAssetResourceLoaderDelegate {
	func assetResourceLoader(_ loader: STMAssetResourceLoader, didReceiveContentType contentType: String, contentLength: Int64) {
		delegate?.resourceLoaderManager?(self, didReceiveContentType: contentType, contentLength: contentLength)
	}

	func assetResourceLoader(_ loader: STMAssetResourceLoader, didLoadData data: Data, fromLocal: Bool) {
		delegate?.resourceLoaderManager?(self, didLoadData: data, fromLocal: fromLocal)
	}

	func assetResourceLoader(_ loader: STMAssetResourceLoader, didCompleteWithError error: Error?) {
		if let index = self.loaders.firstIndex(of: loader) {
			loaders.remove(at: index)
			pendingRequests.remove(at: index)
		}
		delegate?.resourceLoaderManager?(self, didCompleteWithError: error)
	}
}
