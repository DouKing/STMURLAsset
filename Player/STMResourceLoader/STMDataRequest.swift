//
// Player
// STMDataRequest.swift
//
// Created by wuyikai on 2020/10/30.
// 
// 

import Foundation
import Alamofire

class STMDataRequest {
    private let url: URL
    private let from: Int64
    private let to: Int64
    private var dataRequest: DataRequest? {
        didSet {
            oldValue?.cancel()
        }
    }
    
    init(with url: URL, from: Int64, to: Int64) {
        self.url = url
        self.from = from
        self.to = to
    }
    
    func start() {
        let range = "\(kBytesKey)=\(from)-\(to)"
        dataRequest = session.request(url, headers: [kRequestRangeKey: range])
            .responseData(completionHandler: { [weak self] (response) in
                guard let self = self, let request = self.dataRequest, let task = request.task else { return }
                self.taskDidComplete?(self.session.session, task, response.error)
            })
    }
    
    func cancel() {
        dataRequest?.cancel()
    }
    
    private lazy var eventMonitor: ClosureEventMonitor = {
        let monitor = ClosureEventMonitor()
        return monitor
    }()
    
    private lazy var session: Session = {
        let config = URLSessionConfiguration.af.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return Session(configuration: config, eventMonitors: [eventMonitor])
    }()
    
    var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)? {
        set {
            eventMonitor.dataTaskDidReceiveData = newValue
        }
        get {
            return eventMonitor.dataTaskDidReceiveData
        }
    }

    var taskDidComplete: ((URLSession, URLSessionTask, Error?) -> Void)?
}
