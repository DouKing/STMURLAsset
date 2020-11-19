//
//  VideoViewController.swift
//  iOS Example
//
//  Created by DouKing on 2020/10/26.
//

import UIKit
import AVFoundation
import STMURLAsset

class VideoViewController: UIViewController {

	deinit {
		debugPrint(#function)
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		view.addSubview(playerView)
		playerView.playerLayer.player = player
    }

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		playerView.frame = view.bounds
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		playNext()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		player.pause()
	}

	@IBAction func playNext() {
		player.pause()
		index = (index + 1) % assets.count
		let asset = assets[index]
		let item = AVPlayerItem(asset: asset)
		self.player.replaceCurrentItem(with: item)
		player.play()
	}

	let playerView = PlayerView()
	let player: AVPlayer = AVPlayer()
	var index = 0

	lazy var assets: [STMURLAsset] = {
		return ["http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4", "https://vt1.doubanio.com/202001021917/01b91ce2e71fd7f671e226ffe8ea0cda/view/movie/M/301120229.mp4"
		].map {
			let url = URL(string: $0)!
			let asset = STMURLAsset(url: url)
			asset.resourceLoaderDelegate = self
			asset.preloadAsynchronously()
			return asset
		}
	}()
}

extension VideoViewController: STMAssetResourceLoaderManagerDelegate {
	func resourceLoaderManager(_ resourceLoaderManager: STMAssetResourceLoaderManager, didReceiveContentType contentType: String, contentLength: Int64) {
		debugPrint("receive response \(contentType)/\(contentLength)")
	}

	func resourceLoaderManager(_ resourceLoaderManager: STMAssetResourceLoaderManager, didLoadData data: Data, fromLocal: Bool) {
		debugPrint("receive \(fromLocal ? "local" : "remote") data \(data.count) bytes")
	}

	func resourceLoaderManager(_ resourceLoaderManager: STMAssetResourceLoaderManager, didCompleteWithError error: Error?) {
		debugPrint("receive data complete \((error != nil) ? "\(error!)" : "success")")
	}
}

class PlayerView: UIView {
	override class var layerClass: AnyClass {
		return AVPlayerLayer.self
	}

	var playerLayer: AVPlayerLayer {
		return layer as! AVPlayerLayer
	}
}
