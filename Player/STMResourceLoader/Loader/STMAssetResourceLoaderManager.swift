//
//  STMAssetResourceLoaderManager.swift
//  Player
//
//  Created by DouKing on 2020/10/26.
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
		self.cacheHandler = try STMAssetResourceCache(url: url)
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
        loader.assetResourceLoaderDidComplete = { [weak self] (resourceLoader, _) in
            guard let self = self else { return }
            if let index = self.loaders.firstIndex(of: resourceLoader) {
                self.loaders.remove(at: index)
                self.pendingRequests.remove(at: index)
            }
        }
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
