//
//  XMLNode.swift
//  XMLCodable
//
//  Created by Artem Shimanski on 5/25/19.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import Foundation

protocol XMLNode {
    var value: String? {get}
    var keys: [String] {get}
    var values: [XMLNode] {get}
    subscript(key: String) -> [XMLNode]? {get}
}

extension String: XMLNode {
    
    var value: String? {
        return self
    }
    
    var keys: [String] {
        return []
    }
    
    var values: [XMLNode] {
        return []
    }
    
    subscript(key: String) -> [XMLNode]? {
        return nil
    }

}
