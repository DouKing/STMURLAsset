//
//  VideoViewController.swift
//  iOS Example
//
//  Created by DouKing on 2020/10/26.
//

import UIKit
import AVFoundation
import STMURLAsset
import SwiftyJSON
import Kingfisher

class VideoViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
		tableView.register(UINib(nibName: String(describing: PlayerCell.self), bundle: nil), forCellReuseIdentifier: PlayerCell.id)
		fetchData {
			self.tableView.reloadData()
		}
    }

	private func fetchData(_ completion: @escaping () -> Void) {
		DispatchQueue.global().async {
			let path = Bundle.main.path(forResource: "data", ofType: "json")!
			let data = try! NSData(contentsOfFile: path) as Data
			let obj = try! JSONSerialization.jsonObject(with: data, options: .mutableContainers)
			let json = JSON(obj)
			let list = json["list"].arrayValue
			self.assets = list.map {
				let url = URL(string: $0["video_url"].stringValue)!
				let asset = STMURLAsset(url: url)
				asset.resourceLoaderDelegate = self
				//asset.preloadAsynchronously()
				return asset
			}
			self.images = Array(repeating: nil, count: self.assets.count)
			DispatchQueue.main.async {
				self.dataSource = list
				completion()
			}
		}
	}

	let player: AVPlayer = AVPlayer()
	lazy var playerView: PlayerView = {
		let pv = PlayerView()
		pv.playerLayer.player = player
		return pv
	}()
	var playIndex: IndexPath?
	var playCell: PlayerCell?

	var dataSource: [JSON] = []
	var assets: [STMURLAsset] = []
	var images: [Item?] = []
}

extension VideoViewController {
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let json = dataSource[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: PlayerCell.id, for: indexPath) as! PlayerCell
		cell.titleLabel.text = json["title"].string
		if !images.isEmpty, let item = images[indexPath.row] {
			cell.coverImageView.image = item.image
		} else {
			cell.coverImageView.kf.setImage(with: json["thumbnail_url"].url)
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let json = dataSource[indexPath.row]
		let width = CGFloat(json["video_width"].floatValue)
		let height = CGFloat(json["video_height"].floatValue)

		return height / width * tableView.frame.width + 30
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let block = {
			let cell = tableView.cellForRow(at: indexPath) as! PlayerCell

			self.player.replaceCurrentItem(with: AVPlayerItem(asset: self.assets[indexPath.row]))
			if !self.images.isEmpty, let item = self.images[indexPath.row] {
				self.player.seek(to: item.time)
			}

			self.view.isUserInteractionEnabled = false
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
				cell.playerContentView.addSubview(self.playerView)
				self.playerView.frame = cell.playerContentView.bounds
				self.player.play()
				self.view.isUserInteractionEnabled = true
			}

			self.playIndex = indexPath
			self.playCell = cell
		}

		if let playIndex = playIndex {
			player.pause()
			let generator = AVAssetImageGenerator(asset: player.currentItem!.asset)
			generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: player.currentTime())]) { (requestedTime, cgImage, actualTime, result, error) in
				DispatchQueue.main.async {
					guard let cgImage = cgImage else {
						block()
						return
					}
					let image = UIImage(cgImage: cgImage)
					self.images[playIndex.row] = Item(image: image, time: actualTime)
					let cell = tableView.cellForRow(at: playIndex) as! PlayerCell
					cell.coverImageView.image = image
					cell.playerContentView.subviews.forEach { v in
						if v is PlayerView {
							v.removeFromSuperview()
						}
					}
					block()
				}
			}
		} else {
			block()
		}
	}

	override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		guard let playIndex = playIndex, playIndex.row == indexPath.row else { return }

		player.pause()
		if let cgImage = try? AVAssetImageGenerator(asset: player.currentItem!.asset).copyCGImage(at: player.currentTime(), actualTime: nil) {
			images[indexPath.row] = Item(image: UIImage(cgImage: cgImage), time: player.currentTime())
		}

		playCell?.playerContentView.subviews.forEach { v in
			if v is PlayerView {
				v.removeFromSuperview()
			}
		}
	}
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

//--------------------------------------------------------------------------------
// MARK: -
//--------------------------------------------------------------------------------

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

struct Item {
	let image: UIImage
	let time: CMTime
}
