//
//  PlayerCell.swift
//  iOS Example
//
//  Created by DouKing on 2020/11/25.
//

import UIKit

class PlayerCell: UITableViewCell {

	static let id = "PlayerCell"

	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var playerContentView: UIView!
	@IBOutlet weak var coverImageView: UIImageView!
	
	override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
