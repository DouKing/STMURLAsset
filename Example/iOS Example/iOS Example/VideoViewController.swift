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

//		let url = URL(string: "https://vt1.doubanio.com/202001021917/01b91ce2e71fd7f671e226ffe8ea0cda/view/movie/M/301120229.mp4")!
		let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
		let asset = STMURLAsset(url: url)
//		asset.loadValuesAsynchronously(forKeys: ["playable"]) {
//			var error: NSError? = nil
//			let status = asset.statusOfValue(forKey: "playable", error: &error)
//			switch status {
//				case .loaded:
//					// Sucessfully loaded, continue processing
//					debugPrint("loaded")
//				case .failed:
//					// Examine NSError pointer to determine failure
//					debugPrint("failed")
//				case .cancelled:
//					// Loading cancelled
//					debugPrint("cancelled")
//				default:
//					// Handle all other cases
//					debugPrint("other")
//			}
//
//		}
		let item = AVPlayerItem(asset: asset)
		self.player.replaceCurrentItem(with: item)
    }

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		playerView.frame = view.bounds
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		player.play()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		player.pause()
	}

	let playerView = PlayerView()
	let player: AVPlayer = AVPlayer()
}

class PlayerView: UIView {
	override class var layerClass: AnyClass {
		return AVPlayerLayer.self
	}

	var playerLayer: AVPlayerLayer {
		return layer as! AVPlayerLayer
	}
}
