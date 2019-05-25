//
//  XMLCodable.swift
//  XMLCodable
//
//  Created by Artem Shimanski on 5/25/19.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import Foundation

struct _CodingKey: CodingKey {
    var stringValue: String
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    var intValue: Int?
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "Index \(intValue)"
    }
}

var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()
