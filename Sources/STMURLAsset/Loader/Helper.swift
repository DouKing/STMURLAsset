//
// Helper.swift
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
import CommonCrypto

extension String {
	var md5: String {
		let length = Int(CC_MD5_DIGEST_LENGTH)
		let messageData = self.data(using: .utf8)!
		var digestData = Data(count: length)

		_ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
			messageData.withUnsafeBytes { messageBytes -> UInt8 in
				if let messageBytesBaseAddress = messageBytes.baseAddress,
				   let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
					let messageLength = CC_LONG(messageData.count)
					CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
				}
				return 0
			}
		}
		return digestData.map { String(format: "%02hhx", $0) }.joined()
	}
}

extension Dictionary {
    func value(for keys: [Key]) -> Value? {
        for key in keys {
            if let value = self[key] {
                return value
            }
        }
        return nil
    }
}

let kResponseContentRangeKeys = [
    "Content-Range",
    "content-range",
    "Content-range",
    "content-Range",
]

let kAcceptRangesKeys: [String] = [
    "Accept-Ranges",
    "accept-ranges",
    "Accept-ranges",
    "accept-Ranges",
]

let kRequestRangeKey = "Range"
let kBytesKey = "bytes"

extension URLResponse {
    var stm_expectedContentLength: Int64 {
        guard let response = self as? HTTPURLResponse else {
            return expectedContentLength
        }
        
        if let rangeString = response.allHeaderFields.value(for: kResponseContentRangeKeys) as? String,
           let bytesString = rangeString.split(separator: "/").map({String($0)}).last,
           let bytes = Int64(bytesString)
        {
            return bytes
        } else {
            return expectedContentLength
        }
    }
    
    var stm_contentRange: String {
        guard let response = self as? HTTPURLResponse else {
            return ""
        }
        guard let range = response.allHeaderFields.value(for: kResponseContentRangeKeys) as? String else { return "" }
        guard let content = range.components(separatedBy: "/").first else { return "" }
        return content.components(separatedBy: " ").last ?? ""
    }
    
    var stm_isByteRangeAccessSupported: Bool {
        guard let response = self as? HTTPURLResponse else {
            return false
        }
        
        for key in kAcceptRangesKeys {
            if let value = response.allHeaderFields[key] as? String, value == kBytesKey {
                return true
            }
        }
        
        return false
    }
}

extension URLRequest {
    var stm_range: String {
        guard let range = allHTTPHeaderFields?[kRequestRangeKey] else { return "" }
        return range.components(separatedBy: "=").last ?? ""
    }
}
