//
//  STMURLAssetLoaderDelegate.swift
//  Player
//
//  Created by DouKing on 2020/10/28.
//

import Foundation

enum STMResourceLoadingError: Error {
	case responseValidationFailed
	case wrongRange
}

public protocol STMAssetResourceLoaderManagerDelegate: AnyObject {
	
}
