//
//  XMLCodableTests.swift
//  XMLCodableTests
//
//  Created by Artem Shimanski on 5/25/19.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import XCTest
import XMLCodable

class XMLCodableTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testBase() {
        let xml = """
<?xml version="1.0"?>
<root title="root">
    <child>
        <id>1</id>
    </child>
</root>
"""
        struct Root: Codable, Equatable {
            var child: Child
            var title: String
            struct Child : Codable, Equatable {
                var id: Int
            }
        }
            
        let value = try! XMLDecoder().decode(Root.self, from: xml.data(using: .utf8)!)
        XCTAssertEqual(value, Root(child: Root.Child(id: 1), title: "root"))
    }

    func testArray1() {
        let xml = """
<?xml version="1.0"?>
<root title="root">
    <child id="1"/>
    <child id="2"/>
</root>
"""
        struct Root: Codable, Equatable {
            var children: [Child]
            var title: String
            struct Child : Codable, Equatable {
                var id: Int
            }
            
            enum CodingKeys: String, CodingKey {
                case children = "child"
                case title
            }
        }
        
        let value = try! XMLDecoder().decode(Root.self, from: xml.data(using: .utf8)!)
        XCTAssertEqual(value, Root(children: [Root.Child(id: 1), Root.Child(id: 2)], title: "root"))
    }
    
    func testArray2() {
        let xml = """
<?xml version="1.0"?>
<root title="root">
    <number>1</number>
    <number>2</number>
</root>
"""
        struct Root: Codable, Equatable {
            var numbers: [Double]
            var title: String
            
            enum CodingKeys: String, CodingKey {
                case numbers = "number"
                case title
            }
        }
        
        let value = try! XMLDecoder().decode(Root.self, from: xml.data(using: .utf8)!)
        XCTAssertEqual(value, Root(numbers: [1, 2], title: "root"))
    }
    
    func testDictionary1() {
        let xml = """
<?xml version="1.0"?>
<root>
    <dic>
        <key1>value1</key1>
        <key2><![CDATA[
value2
]]></key2>
    </dic>
</root>
"""
        struct Root: Codable, Equatable {
            var dic: [String: String]
        }
        
        let value = try! XMLDecoder().decode(Root.self, from: xml.data(using: .utf8)!)
        XCTAssertEqual(value, Root(dic: ["key1": "value1", "key2": "value2"]))
    }
    
    func testDictionary2() {
        let xml = """
<?xml version="1.0"?>
<root>
    <dic>
        <key1><child id="1"/></key1>
        <key2><child id="2"/></key2>
    </dic>
</root>
"""
        struct Root: Codable, Equatable {
            var dic: [String: Item]
            struct Item: Codable, Equatable {
                var child: Child
            }
            struct Child : Codable, Equatable {
                var id: Int
            }
        }
        
        let value = try! XMLDecoder().decode(Root.self, from: xml.data(using: .utf8)!)
        XCTAssertEqual(value, Root(dic: ["key1": Root.Item(child: Root.Child(id: 1)), "key2": Root.Item(child: Root.Child(id: 2))]))
    }
}
