//
//  STMAssetResourceDataRequest.swift
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
internal import Alamofire

class STMAssetResourceDataRequest: @unchecked Sendable {
    private let url: URL
	private let cacheHandler: STMAssetResourceCache
    private var dataRequest: DataRequest? {
        didSet {
            oldValue?.cancel()
        }
    }

	private var fragments: [STMAssetResourceFragment] = []

	var didReceiveData: ((STMAssetResourceDataRequest, Data, Bool) -> Void)?
	var didComplete: ((STMAssetResourceDataRequest, URLResponse?, Error?) -> Void)?

	init(with url: URL, cacheHandler: STMAssetResourceCache) {
        self.url = url
		self.cacheHandler = cacheHandler
    }
    
	func download(from: Int64, to: Int64) {
		let length = to - from + 1
		let range = NSRange(location: Int(from), length: Int(length))
		fragments = cacheHandler.fragmens(for: range)
        processFragments()
    }
    
    func cancel() {
        dataRequest?.cancel()
    }

    private func processFragments() {
		guard !fragments.isEmpty else {
			didComplete?(self, nil, nil)
			return
		}

		let action = fragments.removeFirst()

		guard action.actionType == .remote else {
			DispatchQueue.main.async {
				let data = self.cacheHandler.cachedData(for: action.range)
				self.didReceiveData?(self, data, true)
				self.processFragments()
			}
			return
		}

		let from = action.range.location
		let to = action.range.length + from - 1

		let range = "\(kBytesKey)=\(from)-\(to)"
		dataRequest = session.request(url, headers: [kRequestRangeKey: range])
			.responseData(completionHandler: { [weak self] (response) in
				guard let self = self else { return }
				guard let request = self.dataRequest, let task = request.task else { return }
				if self.fragments.isEmpty && response.error != nil {
					self.processFragments()
				} else {
					self.didComplete?(self, task.response, response.error)
				}

				if let data = response.data {
					let length = data.count
					let range = NSRange(location: from, length: length)
					self.cacheHandler.cache(data: data, for: range)
					self.cacheHandler.save()
				}
			})
	}
    
    private lazy var eventMonitor: ClosureEventMonitor = {
        let monitor = ClosureEventMonitor()
		monitor.dataTaskDidReceiveData = { [weak self] (session, dataTask, data) in
			guard let self = self else { return }

			switch self.validData(of: data, from: dataTask) {
			case .failure(let error):
				self.didComplete?(self, dataTask.response, error)
				dataTask.cancel()
			case .success(let validData):
				self.didReceiveData?(self, validData, false)
			}
		}
        return monitor
    }()
    
    private lazy var session: Session = {
        let config = URLSessionConfiguration.af.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return Session(configuration: config, eventMonitors: [eventMonitor])
    }()
}

extension STMAssetResourceDataRequest {
	private func validData(
		of receiveData: Data, from dataTask: URLSessionDataTask
	) -> Result<Data, Error> {
		guard let httpResponse = dataTask.response as? HTTPURLResponse else {
			return .success(receiveData)
		}

		let statusCode = httpResponse.statusCode
		if statusCode < 200 || statusCode >= 400 {
			return .failure(STMResourceLoadingError.responseValidationFailed)
		}

		if let currentRequest = dataTask.currentRequest,
		   !rangeOfRequest(currentRequest, isEqualToRangeOf: httpResponse)
		{
			if let data = subData(of: receiveData, from: currentRequest, response: httpResponse) {
				return .success(data)
			}
			return .failure(STMResourceLoadingError.wrongRange)
		}

		return .success(receiveData)
	}

	private func subData(
		of data: Data, from request: URLRequest, response: HTTPURLResponse
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
		let to = requestTo - requestFrom + 1
		return data.subdata(in: from ..< to)
	}

	private func rangeOfRequest(_ request: URLRequest, isEqualToRangeOf response: HTTPURLResponse) -> Bool {
		let requestRange = request.stm_range
		let responseRange = response.stm_contentRange
		return requestRange == responseRange
	}
}
