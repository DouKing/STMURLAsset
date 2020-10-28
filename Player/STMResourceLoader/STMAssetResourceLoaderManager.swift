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
	private var dataTasks: [URLSessionDataTask] = []
	private var datas: [Data] = []
	private var datasForSavingToCache: [NSValue: Data] = [:]

	public init(with url: URL) {
		self.originalURL = url
		self.originalScheme = url.scheme
		super.init()
	}

	func cancel() {
		session.invalidateAndCancel()
		session = nil
	}

	//MARK: setter & getter

	public private(set)
	lazy var session: URLSession! = {
		URLSession(configuration: .default, delegate: self, delegateQueue: .main)
	}()
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

		let realURL = url(for: loadingRequest)

		var request = URLRequest(url: realURL, cachePolicy: .reloadIgnoringLocalCacheData)
		if loadingRequest.contentInformationRequest == nil && loadingRequest.dataRequest == nil {
			return false
		}

		guard let requestLength = loadingRequest.dataRequest?.requestedLength, requestLength > 0 else {
			return false
		}

		let startOffset = { () -> Int64 in
			if let start = loadingRequest.dataRequest?.currentOffset, start != 0 {
				return start
			}
			return loadingRequest.dataRequest?.requestedOffset ?? 0
		}()

		if let dataRequest = loadingRequest.dataRequest, dataRequest.requestsAllDataToEndOfResource {
			request.setValue("bytes=\(startOffset)-", forHTTPHeaderField: "Range")
		} else {
			let endOffset = startOffset + Int64(requestLength) - 1
			request.setValue("bytes=\(startOffset)-\(endOffset)", forHTTPHeaderField: "Range")
		}

		let task = session.dataTask(with: request)
		task.resume()
		datas.append(Data())
		dataTasks.append(task)
		pendingRequests.append(loadingRequest)

		return true
	}

	public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
		guard let index = pendingRequests.firstIndex(of: loadingRequest) else { return }
		dataTasks[index].cancel()
	}
}

//--------------------------------------------------------------------------------
// MARK: - URLSessionDelegate
//--------------------------------------------------------------------------------

extension STMAssetResourceLoaderManager: URLSessionDataDelegate {
	public func urlSession(
		_ session: URLSession,
		dataTask: URLSessionDataTask,
		didReceive response: URLResponse,
		completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
	) {
		if let index = dataTasks.firstIndex(of: dataTask) {
			let loadingRequest = pendingRequests[index]
			loadingRequest.response = response

			if let contentInformationRequest = loadingRequest.contentInformationRequest {
				fillInWithRemoteResponse(contentInformationRequest, response: response)
				loadingRequest.finishLoading()
				let task = dataTasks[index]
				task.cancel()
				dataTasks.remove(at: index)
				datas.remove(at: index)
				pendingRequests.remove(at: index)
			}
		}

		completionHandler(.allow)
	}

	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		guard let index = dataTasks.firstIndex(of: dataTask) else { return }
		let loadingRequest = pendingRequests[index]
		var mutableData = datas[index]

		let requestOffset = loadingRequest.dataRequest?.requestedOffset ?? 0
		let currentOffset = loadingRequest.dataRequest?.currentOffset ?? 0
//		let requestLength = loadingRequest.dataRequest?.requestedLength ?? 0
		precondition(mutableData.count == currentOffset - requestOffset)

		switch validData(of: data, from: dataTask, loadingRequest: loadingRequest) {
		case .failure(let error):
			debugPrint(error)
			loadingRequest.finishLoading(with: error)
			dataTask.cancel()
			dataTasks[index].cancel()
			dataTasks.remove(at: index)
			datas.remove(at: index)
			pendingRequests.remove(at: index)
			return
		case .success(let validData):
			mutableData.append(validData)
			loadingRequest.dataRequest?.respond(with: validData)
		}
	}

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		guard let dataTask = task as? URLSessionDataTask else { return }
		guard let index = dataTasks.firstIndex(of: dataTask) else { return }
		let loadingRequest = pendingRequests[index]
		if let error = error {
			loadingRequest.finishLoading(with: error)
		} else {
			loadingRequest.finishLoading()
		}

		datas.remove(at: index)
		dataTasks.remove(at: index)
		pendingRequests.remove(at: index)
	}
}

extension STMAssetResourceLoaderManager {
	private func fillInWithRemoteResponse(_ request: AVAssetResourceLoadingContentInformationRequest, response: URLResponse) {
		if let mimeType = response.mimeType,
		   let contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType as CFString, nil)
		{
			request.contentType = contentType.takeRetainedValue() as String
		}

		guard let httpResponse = response as? HTTPURLResponse,
			  let contentRange = httpResponse.allHeaderFields["Content-Range"] as? String
		else {
			request.contentLength = response.expectedContentLength
			return
		}

		if let accept = httpResponse.allHeaderFields["Accept-Ranges"] as? String, accept == "bytes" {
			request.isByteRangeAccessSupported = true
		} else {
			request.isByteRangeAccessSupported = false
		}

		if let contentLength = contentRange.components(separatedBy: "/").last, let length = Int64(contentLength) {
			request.contentLength = length
		} else {
			request.contentLength = response.expectedContentLength
		}
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

//		if let currentRequest = dataTask.currentRequest,
//		   let dataRequest = loadingRequest.dataRequest,
//		   !rangeOfRequest(currentRequest, isEqualToRangeOf: httpResponse, requestToEnd: dataRequest.requestsAllDataToEndOfResource)
//		{
//			if let data = subData(of: receiveData, from: currentRequest, response: httpResponse, loadingRequest: loadingRequest) {
//				return .success(data)
//			}
//			return .failure(STMResourceLoadingError.wrongRange)
//		}

		return .success(receiveData)
	}

	private func subData(
		of data: Data, from request: URLRequest, response: HTTPURLResponse, loadingRequest: AVAssetResourceLoadingRequest
	) -> Data? {
		let requestRange = range(from: request)
		let responseRange = range(from: response)
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
		let requestRange = range(from: request)
		let responseRange = range(from: response)
		return requestToEnd ? responseRange.hasPrefix(requestRange) : requestRange == responseRange
	}

	private func range(from request: URLRequest) -> String {
		guard let range = request.allHTTPHeaderFields?["Range"] else { return "" }
		return range.components(separatedBy: "=").last ?? ""
	}

	private func range(from response: HTTPURLResponse) -> String {
		guard let range = response.allHeaderFields["Content-Range"] as? String else { return "" }
		guard let content = range.components(separatedBy: "/").first else { return "" }
		return content.components(separatedBy: " ").last ?? ""
	}
}
