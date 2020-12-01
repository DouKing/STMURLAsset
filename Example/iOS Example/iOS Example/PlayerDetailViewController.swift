//
//  PlayerDetailViewController.swift
//  iOS Example
//
//  Created by DouKing on 2020/11/27.
//

import UIKit
import AVKit

class PlayerDetailViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
		view.backgroundColor = .green
    }

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
	}

	func finalFrame() -> CGRect {
		CGRect(x: 0, y: view.frame.height - 400, width: view.frame.width, height: 200)
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		playerView.playerLayer.player?.seek(to: CMTime(seconds: 0, preferredTimescale: CMTimeScale(600)))
		playerView.playerLayer.player?.play()
	}
}
