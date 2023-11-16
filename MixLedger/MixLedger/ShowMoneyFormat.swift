//
//  ShowMoneyFormat.swift
//  MixLedger
//
//  Created by 莊羚羊 on 2023/11/16.
//

import Foundation
import UIKit

enum Money{
    case money(Double)
    
    var text: String {
        switch self {
        case .money(let int):
            return String(int)
        }
    }
    
    var color: UIColor {
        switch self {
        case .money(let int):
            if int > 0{
                return UIColor.blue
            }else{
                return UIColor.red
            }
        }
    }
}