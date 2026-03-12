//
//  Item.swift
//  infosys2
//
//  Created by user@78 on 10/03/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
