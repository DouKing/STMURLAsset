//
//  STMURLAsset.swift
//  Player
//
//  Created by DouKing on 2020/10/28.
//

import AVFoundation

public class STMURLAsset: AVURLAsset {

	private var assetLoaderManager: STMAssetResourceLoaderManager?

	deinit {
		assetLoaderManager?.cancel()
	}

	public override init(url: URL, options: [String : Any]? = nil) {
		guard !url.isFileURL else {
			super.init(url: url, options: options)
			return
		}

		guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			super.init(url: url, options: options)
			return
		}

		urlComponents.scheme = STMAssetResourceLoaderManager.scheme
		guard let assetURL = urlComponents.url else {
			super.init(url: url, options: options)
			return
		}

		super.init(url: assetURL, options: options)
		assetLoaderManager = STMAssetResourceLoaderManager(with: url)
		resourceLoader.setDelegate(assetLoaderManager, queue: .main)
	}

	// MARK: setter & getter

	weak var assetLoaderDelegate: STMAssetResourceLoaderManagerDelegate? {
		get {
			assetLoaderManager?.delegate
		}
		set {
			assetLoaderManager?.delegate = newValue
		}
	}
}
