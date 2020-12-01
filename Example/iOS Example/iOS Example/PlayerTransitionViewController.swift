//
//  PlayerTransitionViewController.swift
//  iOS Example
//
//  Created by DouKing on 2020/11/27.
//

import UIKit
import AVKit
import STMURLAsset

var playerView: PlayerView = {
	let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
	let asset = STMURLAsset(url: url)
	asset.preloadAsynchronously()
	let playerItem = AVPlayerItem(asset: asset)
	let player = AVPlayer(playerItem: playerItem)
	let av = PlayerView()
	av.playerLayer.player = player
	return av
}()

class PlayerTransitionViewController: UIViewController {
	override func viewDidLoad() {
        super.viewDidLoad()
		view.addSubview(playerView)
		playerView.frame = CGRect(x: 10, y: 100, width: 120, height: 80)
    }

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		navigationController?.delegate = nil
	}

	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		navigationController?.delegate = self
		let detailVC = PlayerDetailViewController()
		navigationController?.pushViewController(detailVC, animated: true)
	}

	func finalFrame() -> CGRect {
		CGRect(x: 10, y: 100, width: 120, height: 80)
	}
}

extension PlayerTransitionViewController: UINavigationControllerDelegate {
	func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		let transition = Transition()
		transition.operation = operation
		return transition
	}
}

class Transition: NSObject, UIViewControllerAnimatedTransitioning {
	var operation: UINavigationController.Operation = .none

	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return 0.3
	}

	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		guard let toVC = transitionContext.viewController(forKey: .to) else { return }
		guard let fromVC = transitionContext.viewController(forKey: .from) else { return }
		let containerView = transitionContext.containerView

		if case .push = operation {
			containerView.addSubview(fromVC.view)
			containerView.addSubview(toVC.view)
			containerView.addSubview(playerView)
			playerView.frame = fromVC.view.convert(CGRect(x: 10, y: 100, width: 120, height: 80), to: containerView)
			toVC.view.alpha = 0
		} else {
			containerView.addSubview(toVC.view)
			containerView.addSubview(fromVC.view)
			containerView.addSubview(playerView)
			playerView.frame = fromVC.view.convert(CGRect(x: 0, y: fromVC.view.frame.height - 400, width: fromVC.view.frame.width, height: 200),
												   to: containerView)
		}

		UIView.animate(withDuration: 0.8) {
			if case .push = self.operation {
				playerView.frame = toVC.view.convert(CGRect(x: 0, y: toVC.view.frame.height - 400,
															width: toVC.view.frame.width, height: 200),
													   to: containerView)
				toVC.view.alpha = 1
			} else {
				playerView.frame = toVC.view.convert(CGRect(x: 10, y: 100, width: 120, height: 80), to: containerView)
				fromVC.view.alpha = 0
			}
		} completion: { (finish) in
			toVC.view.addSubview(playerView)
			transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
		}
	}
}
