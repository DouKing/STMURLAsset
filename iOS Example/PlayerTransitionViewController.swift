//
//  PlayerTransitionViewController.swift
//  iOS Example
//
//  Created by DouKing on 2020/11/27.
//

import UIKit
import AVKit
import STMURLAsset

class PlayerTransitionViewController: UIViewController, @unchecked Sendable {
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
    
    lazy var playerView: PlayerView = {
        let url = URL(string: "https://kvideo01.youju.sohu.com/3e2f39f5-364b-48cd-a980-3c664e6953d82_0_0.mp4?sign=b7be69b37eb7766b2eb4d64cdee7b280&t=1719317843")!
        let asset = STMURLAsset(url: url)
        asset.resourceLoaderDelegate = self
        asset.preloadAsynchronously()
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let av = PlayerView()
        av.playerLayer.player = player
        av.layer.borderColor = UIColor.lightGray.cgColor
        av.layer.borderWidth = 1
        return av
    }()
}

extension PlayerTransitionViewController: STMAssetResourceLoaderManagerDelegate {
    nonisolated func resourceLoaderManager(_ resourceLoaderManager: STMAssetResourceLoaderManager, didReceiveContentType contentType: String, contentLength: Int64) {
        print("receive content", contentType, contentLength)
    }
    
    nonisolated func resourceLoaderManager(_ resourceLoaderManager: STMAssetResourceLoaderManager, didLoadData data: Data, fromLocal: Bool) {
        print("load data", data.count, fromLocal)
    }
    
    nonisolated func resourceLoaderManager(_ resourceLoaderManager: STMAssetResourceLoaderManager, didCompleteWithError error: (any Error)?) {
        print("complete", error ?? "xx")
    }
}

extension PlayerTransitionViewController: UINavigationControllerDelegate {
	func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		let transition = PlayerTransition()
		transition.operation = operation
        transition.playerView = playerView
		return transition
	}
}

class PlayerTransition: NSObject, UIViewControllerAnimatedTransitioning {
	var operation: UINavigationController.Operation = .none
    weak var playerView: PlayerView?

	func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return 0.25
	}

	func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		guard let toVC = transitionContext.viewController(forKey: .to) else { return }
		guard let fromVC = transitionContext.viewController(forKey: .from) else { return }
        guard let playerView = playerView else { return }
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

		UIView.animate(withDuration: 0.25) {
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

class PlayerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapAction(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    @objc func handleTapAction(_ sender: UITapGestureRecognizer) {
        guard let player = playerLayer.player else { return }
        if player.rate > 0 {
            player.pause()
        } else {
            player.play()
        }
    }
}
