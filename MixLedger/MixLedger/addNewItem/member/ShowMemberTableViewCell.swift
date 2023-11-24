//
//  ShowMemberTableViewCell.swift
//  MixLedger
//
//  Created by 莊羚羊 on 2023/11/23.
//

import UIKit
import SnapKit

class ShowMemberTableViewCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
        
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "rrrrrr"
        return label
    }()
    
    let moneyLabel: UILabel = {
        let label = UILabel()
        label.text = "222222"
        return label
    }()

    func setupLayout(){
        addSubview(moneyLabel)
        addSubview(nameLabel)
        
        moneyLabel.snp.makeConstraints{(mark) in
            mark.top.equalTo(self).offset(12)
            mark.bottom.equalTo(self).offset(-12)
            mark.trailing.equalTo(self.snp.trailing).offset(-12)
        }
        
        nameLabel.snp.makeConstraints{(mark) in
            mark.centerY.equalTo(self)
            mark.leading.equalTo(self).offset(12)
            mark.trailing.equalTo(moneyLabel.snp.leading).offset(-12)
        }
    }
    
}
