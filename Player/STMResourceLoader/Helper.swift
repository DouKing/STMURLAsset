//
// Player
// Helper.swift
//
// Created by DouKing on 2020/10/29.
// 
// 

import Foundation

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
