//
// Player
// STMAssetResourceLoader.swift
//
// Created by wuyikai on 2020/10/30.
// 
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
		fillInWithVideoInfo(loadingRequest.contentInformationRequest, cacheHandler.configuration.info)
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
        dataRequest?.dataTaskDidReceiveData = { [weak self] (session, dataTask, data) -> Void in
            guard let self = self else { return }
            switch self.validData(of: data, from: dataTask, loadingRequest: self.loadingRequest) {
            case .failure(let error):
                debugPrint("valid error \(error)")
                self.loadingRequest.finishLoading(with: error)
                dataTask.cancel()
                return
            case .success(let validData):
				debugPrint("receive remote data \(validData.count) bytes")
                self.loadingRequest.dataRequest?.respond(with: validData)
            }
        }
        dataRequest?.taskDidComplete = { [weak self] (session, task, error) -> Void in
            guard let self = self else { return }
            
            if let error = error {
                self.loadingRequest.finishLoading(with: error)
            } else {
                if let contentInformationRequest = self.loadingRequest.contentInformationRequest, let response = task.response {
                    self.fillInWithRemoteResponse(contentInformationRequest, response: response)
                }
                
                self.loadingRequest.finishLoading()
            }

			debugPrint("receive remote data complete \((error != nil) ? "\(error!)" : "success")")
            self.assetResourceLoaderDidComplete?(self, error)
        }

		dataRequest?.didReceiveLocalData = { [weak self] (request, data) in
			guard let self = self else { return }
			debugPrint("receive local data \(data.count) bytes")
			self.loadingRequest.dataRequest?.respond(with: data)
		}

		dataRequest?.didCompleteLocal = { [weak self] (request) in
			guard let self = self else { return }
			debugPrint("receive local data complete")
			self.loadingRequest.finishLoading()
			self.assetResourceLoaderDidComplete?(self, nil)
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

		cacheHandler.set(info:STMAssetResourceContentInfo(
			contentLength: request.contentLength,
			contentType: request.contentType ?? "",
			isByteRangeAccessSupported: request.isByteRangeAccessSupported
		))
    }

	private func fillInWithVideoInfo(_ request: AVAssetResourceLoadingContentInformationRequest?, _ videoInfo: STMAssetResourceContentInfo?) {
		guard let request = request, let videoInfo = videoInfo else { return }
		request.contentType = videoInfo.contentType
		request.contentLength = videoInfo.contentLength
		request.isByteRangeAccessSupported = videoInfo.isByteRangeAccessSupported
	}
    
    private func validData(
        of receiveData: Data, from dataTask: URLSessionDataTask, loadingRequest: AVAssetResourceLoadingRequest
    ) -> Result<Data, Error> {
        guard let httpResponse = dataTask.response as? HTTPURLResponse else {
            return .success(receiveData)
        }
        
        let statusCode = httpResponse.statusCode
        if statusCode < 200 || statusCode >= 400 {
            return .failure(STMResourceLoadingError.responseValidationFailed)
        }
        
        if let currentRequest = dataTask.currentRequest,
           let dataRequest = loadingRequest.dataRequest,
           !rangeOfRequest(currentRequest, isEqualToRangeOf: httpResponse, requestToEnd: dataRequest.requestsAllDataToEndOfResource)
        {
            if let data = subData(of: receiveData, from: currentRequest, response: httpResponse, loadingRequest: loadingRequest) {
                return .success(data)
            }
            return .failure(STMResourceLoadingError.wrongRange)
        }
        
        return .success(receiveData)
    }
    
    private func subData(
        of data: Data, from request: URLRequest, response: HTTPURLResponse, loadingRequest: AVAssetResourceLoadingRequest
    ) -> Data? {
        let requestRange = request.stm_range
        let responseRange = response.stm_contentRange
        let requestRanges = requestRange.components(separatedBy: "-")
        let responseRanges = responseRange.components(separatedBy: "-")
        let requestFrom = Int(requestRanges.first ?? "0") ?? 0
        let requestTo = Int(requestRanges.last ?? "0") ?? 0
        let responseFrom = Int(responseRanges.first ?? "0") ?? 0
        let responseTo = Int(responseRanges.last ?? "0") ?? 0
        
        guard requestFrom >= responseFrom, requestFrom < responseTo,
              requestFrom - responseFrom > data.count, responseTo <= requestTo
        else {
            return nil
        }
        
        let from = requestFrom - responseFrom
        var to = requestTo - requestFrom + 1
        if let dataRequest = loadingRequest.dataRequest, dataRequest.requestsAllDataToEndOfResource {
            to = data.count - from
        }
        return data.subdata(in: from ..< to)
    }
    
    private func rangeOfRequest(_ request: URLRequest, isEqualToRangeOf response: HTTPURLResponse, requestToEnd: Bool) -> Bool {
        let requestRange = request.stm_range
        let responseRange = response.stm_contentRange
        return requestToEnd ? responseRange.hasPrefix(requestRange) : requestRange == responseRange
    }
}
