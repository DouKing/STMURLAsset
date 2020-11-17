//
// Player
// STMAssetResourceDataRequest.swift
//
// Created by wuyikai on 2020/10/30.
// 
// 

import Foundation
import Alamofire

class STMAssetResourceDataRequest {
    private let url: URL
	private let cacheHandler: VideoCacheHandler
    private var dataRequest: DataRequest? {
        didSet {
            oldValue?.cancel()
        }
    }

	private var actions: [VideoCacheAction] = []
    
	init(with url: URL, cacheHandler: VideoCacheHandler) {
        self.url = url
		self.cacheHandler = cacheHandler
    }
    
	func download(from: Int64, to: Int64) {
		let length = to - from + 1
		let range = NSRange(location: Int(from), length: Int(length))
		actions = cacheHandler.actions(for: range)
		processActions()
    }
    
    func cancel() {
        dataRequest?.cancel()
    }

	private func processActions() {
		guard !actions.isEmpty else {
			didCompleteLocal?(self)
			return
		}

		let action = actions.removeFirst()

		guard action.actionType == .remote else {
			let data = cacheHandler.cachedData(for: action.range)
			didReceiveLocalData?(self, data)
			processActions()
			return
		}

		let from = action.range.location
		let to = action.range.length + from - 1

		let range = "\(kBytesKey)=\(from)-\(to)"
		dataRequest = session.request(url, headers: [kRequestRangeKey: range])
			.responseData(completionHandler: { [weak self] (response) in
				guard let self = self else { return }
				guard let request = self.dataRequest, let task = request.task else { return }
				if self.actions.isEmpty && response.error != nil {
					self.processActions()
				} else {
					self.taskDidComplete?(self.session.session, task, response.error)
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
			self.dataTaskDidReceiveData?(session, dataTask, data)
		}
        return monitor
    }()
    
    private lazy var session: Session = {
        let config = URLSessionConfiguration.af.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return Session(configuration: config, eventMonitors: [eventMonitor])
    }()
    
    var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    var taskDidComplete: ((URLSession, URLSessionTask, Error?) -> Void)?

	var didReceiveLocalData: ((STMAssetResourceDataRequest, Data) -> Void)?
	var didCompleteLocal: ((STMAssetResourceDataRequest) -> Void)?
}
