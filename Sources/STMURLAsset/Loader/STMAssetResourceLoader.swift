//
//  STMAssetResourceLoader.swift
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
import AVFoundation
import CoreServices

class STMAssetResourceLoader: NSObject {
    private(set) var url: URL!
    private(set) var loadingRequest: AVAssetResourceLoadingRequest!
    private var dataRequest: STMAssetResourceDataRequest?
	private let cacheHandler: STMAssetResourceCache

    var assetResourceLoaderDidComplete: ((STMAssetResourceLoader, Error?) -> Void)?

	init(with url: URL, loadingRequest: AVAssetResourceLoadingRequest, cacheHandler: STMAssetResourceCache) {
		self.url = url
		self.loadingRequest = loadingRequest
		self.cacheHandler = cacheHandler
        super.init()
		fillInWithVideoInfo(loadingRequest.contentInformationRequest, cacheHandler.assetResourceContentInfo)
    }
    
    func startLoad() {
        guard let requestLength = loadingRequest.dataRequest?.requestedLength, requestLength > 0 else {
            return
        }
        
        let startOffset = { () -> Int64 in
            if let start = loadingRequest.dataRequest?.currentOffset, start != 0 {
                return start
            }
            return loadingRequest.dataRequest?.requestedOffset ?? 0
        }()
        let endOffset = startOffset + Int64(requestLength) - 1
        
        cancel()

		dataRequest = STMAssetResourceDataRequest(with: url, cacheHandler: cacheHandler)
		dataRequest?.didReceiveData = { [weak self] (request, data, isLocal) in
			guard let self = self else { return }
			debugPrint("receive \(isLocal ? "local" : "remote") data \(data.count) bytes")
			self.loadingRequest.dataRequest?.respond(with: data)
		}
		dataRequest?.didComplete = { [weak self] (request, response, error) in
			guard let self = self else { return }

			if let error = error {
				self.loadingRequest.finishLoading(with: error)
			} else {
				if let contentInformationRequest = self.loadingRequest.contentInformationRequest, let response = response {
					self.fillInWithRemoteResponse(contentInformationRequest, response: response)
				}
				self.loadingRequest.finishLoading()
			}

			debugPrint("receive data complete \((error != nil) ? "\(error!)" : "success")")
			self.assetResourceLoaderDidComplete?(self, error)
		}

		dataRequest?.download(from: startOffset, to: endOffset)
    }
    
    func cancel() {
        dataRequest?.cancel()
    }
}

extension STMAssetResourceLoader {
    private func fillInWithRemoteResponse(_ request: AVAssetResourceLoadingContentInformationRequest, response: URLResponse) {
        if let mimeType = response.mimeType,
           let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
        {
            request.contentType = contentType.takeRetainedValue() as String
        }
        
        request.contentLength = response.stm_expectedContentLength
        request.isByteRangeAccessSupported = response.stm_isByteRangeAccessSupported

		cacheHandler.assetResourceContentInfo = STMAssetResourceContentInfo(
			contentLength: request.contentLength,
			contentType: request.contentType ?? "",
			isByteRangeAccessSupported: request.isByteRangeAccessSupported
		)
    }

	private func fillInWithVideoInfo(_ request: AVAssetResourceLoadingContentInformationRequest?, _ videoInfo: STMAssetResourceContentInfo?) {
		guard let request = request, let videoInfo = videoInfo else { return }
		request.contentType = videoInfo.contentType
		request.contentLength = videoInfo.contentLength
		request.isByteRangeAccessSupported = videoInfo.isByteRangeAccessSupported
	}
}
