//
//  XMLDecoder.swift
//  XMLCodable
//
//  Created by Artem Shimanski on 5/25/19.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import Foundation

protocol StringRepresentable {
    init?(_ description: String)
}

extension Int: StringRepresentable {}
extension Int8: StringRepresentable {}
extension Int16: StringRepresentable {}
extension Int32: StringRepresentable {}
extension Int64: StringRepresentable {}
extension UInt: StringRepresentable {}
extension UInt8: StringRepresentable {}
extension UInt16: StringRepresentable {}
extension UInt32: StringRepresentable {}
extension UInt64: StringRepresentable {}
extension Double: StringRepresentable {}
extension Float: StringRepresentable {}
extension Bool: StringRepresentable {}
extension String: StringRepresentable {}

open class XMLDecoder {
    
    public enum DataDecodingStrategy {
        case data
        case deferredToData
        case base64
        case custom((Decoder) throws -> Data)
    }
    
    public enum DateDecodingStrategy {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        case iso8601
        case formatted(DateFormatter)
        case custom((Decoder) throws -> Date)
    }
    
    open var dataDecodingStrategy: DataDecodingStrategy = .data
    open var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    
    open func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        let parser = XMLParser(data: data)
        let delegate = ParserDelegate(root: ParserDelegate.Node(key: "", attributes: [:]))
        parser.delegate = delegate
        parser.parse()
        if let error = parser.parserError {
            throw error
        }
        let values = delegate.root.values
        return try _Decoder(codingPath: [], container: values, userInfo: [:], dataDecodingStrategy: dataDecodingStrategy, dateDecodingStrategy: dateDecodingStrategy).decode(T.self, from: values, forCodingPath: [])
    }
    
    public init() {}
}


internal class ParserDelegate: NSObject, XMLParserDelegate {
    class Node: XMLNode {
        
        subscript(key: String) -> [XMLNode]? {
            return children[key]
        }
        
        var key: String
        var value: String?
        var children: [String: [XMLNode]] = [:]
        var keys: [String] {
            return Array(children.keys)
        }
        
        var values: [XMLNode] {
            return Array(children.values.joined())
        }

        init(key: String, attributes: [String: String]) {
            self.key = key
            children = attributes.mapValues{[$0]}
        }
        
    }
    
    var stack: [Node]
    var root: Node
    init(root: Node) {
        self.root = root
        stack = [root]
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let child = Node(key: elementName, attributes: attributeDict)
        stack.last?.children[elementName, default: []].append(child)
        stack.append(child)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = stack.last?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if value?.isEmpty == false {
            stack.last?.value = value
        }
        else {
            stack.last?.value = nil
        }
        stack.removeLast()
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.value = (stack.last?.value).map{$0 + string} ?? string
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else {return}
        stack.last?.value = (stack.last?.value).map{$0 + string} ?? string
    }
}

extension XMLDecoder {
    private struct _Decoder: Decoder {
        var codingPath: [CodingKey]
 
        var userInfo: [CodingUserInfoKey : Any]
        var container: [XMLNode]
        var dataDecodingStrategy: DataDecodingStrategy = .data
        var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
 
        init(codingPath: [CodingKey], container: [XMLNode], userInfo: [CodingUserInfoKey : Any], dataDecodingStrategy: DataDecodingStrategy, dateDecodingStrategy: DateDecodingStrategy) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.container = container
            self.dataDecodingStrategy = dataDecodingStrategy
            self.dateDecodingStrategy = dateDecodingStrategy
        }
 
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            guard let container = container.first else {throw DecodingError.typeMismatch([XMLNode].self, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
            return KeyedDecodingContainer(_KeyedDecodingContainer(codingPath: codingPath, container: container, decoder: self))
        }
 
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
//            guard let container = container as? [Any] else {throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
            return _UnkeyedDecodingContainer(codingPath: codingPath, container: container, decoder: self)
        }
 
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            guard let container = container.first else {throw DecodingError.typeMismatch([XMLNode].self, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
            return _SingleValueDecodingContainer(codingPath: codingPath, container: container, decoder: self)
        }
 
        func decode<T>(_ type: T.Type, from container: [XMLNode], forCodingPath codingPath: [CodingKey]) throws -> T where T : Decodable {
            switch type {
            case is Data.Type:
                switch dataDecodingStrategy {
                case .data:
                    guard let data = container.first?.value?.data(using: .utf8) else {throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
                    return data as! T
                case .deferredToData:
                    let decoder = _Decoder(codingPath: codingPath, container: container, userInfo: userInfo, dataDecodingStrategy: dataDecodingStrategy, dateDecodingStrategy: dateDecodingStrategy)
                    return try T(from: decoder)
                case .base64:
                    guard let string = container.first?.value, let data = Data(base64Encoded: string, options: []) else {throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
                    return data as! T
                case let .custom(block):
                    let decoder = _Decoder(codingPath: codingPath, container: container, userInfo: userInfo, dataDecodingStrategy: dataDecodingStrategy, dateDecodingStrategy: dateDecodingStrategy)
                    return try block(decoder) as! T
                }
            case is Date.Type:
                switch dateDecodingStrategy {
                case .deferredToDate:
                    let decoder = _Decoder(codingPath: codingPath, container: container, userInfo: userInfo, dataDecodingStrategy: dataDecodingStrategy, dateDecodingStrategy: dateDecodingStrategy)
                    return try T(from: decoder)
                case .millisecondsSince1970:
                    guard let t = container.first?.value.flatMap({TimeInterval($0)}) else {throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
                    return Date(timeIntervalSince1970: t / 1000) as! T
                case .secondsSince1970:
                    guard let t = container.first?.value.flatMap({TimeInterval($0)}) else {throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
                    return Date(timeIntervalSince1970: t) as! T
                case .iso8601:
                    guard let string = container.first?.value, let date = iso8601Formatter.date(from: string) else {throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
                    return date as! T
                case let .formatted(formatter):
                    guard let string = container.first?.value, let date = formatter.date(from: string) else {throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
                    return date as! T
                case let .custom(block):
                    let decoder = _Decoder(codingPath: codingPath, container: container, userInfo: userInfo, dataDecodingStrategy: dataDecodingStrategy, dateDecodingStrategy: dateDecodingStrategy)
                    return try block(decoder) as! T
                }
            default:
                let decoder = _Decoder(codingPath: codingPath, container: container, userInfo: userInfo, dataDecodingStrategy: dataDecodingStrategy, dateDecodingStrategy: dateDecodingStrategy)
                return try T(from: decoder)
            }
        }
    }
 
    private struct _KeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var codingPath: [CodingKey]
        var container: XMLNode
        var decoder: _Decoder
 
        var allKeys: [Key] {
            return container.keys.compactMap {Key(stringValue: $0)}
        }
        
        private func get<T: StringRepresentable>(_ key: Key) throws -> T {
            guard let value = (container[key.stringValue]?.first?.value).flatMap({T($0)}) else {throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "line: \(#line)"))}
            return value
        }

        func contains(_ key: Key) -> Bool {
            return container[key.stringValue] != nil
        }
 
        func decodeNil(forKey key: Key) throws -> Bool {
            return container[key.stringValue] == nil
        }
 
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            return try get(key)
        }
 
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            return try get(key)
        }
 
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            return try get(key)
        }
 
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            return try get(key)
        }
 
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            return try get(key)
        }
 
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            return try get(key)
        }
 
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            return try get(key)
        }
 
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            return try get(key)
        }
 
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            return try get(key)
        }
 
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            return try get(key)
        }
 
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            return try get(key)
        }
 
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            return try get(key)
        }
 
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            return try get(key)
        }
 
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            return try get(key)
        }
 
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            guard let value = container[key.stringValue] else {throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "line: \(#line)"))}
            return try decoder.decode(type, from: value, forCodingPath: codingPath + [key])
        }
 
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            guard let value = container[key.stringValue]?.first else {throw DecodingError.typeMismatch(XMLNode.self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "line: \(#line)"))}
            let container = _KeyedDecodingContainer<NestedKey>(codingPath: codingPath + [key], container: value, decoder: decoder)
            return KeyedDecodingContainer(container)
        }
 
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            guard let value = container[key.stringValue] else {throw DecodingError.typeMismatch([XMLNode].self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "line: \(#line)"))}
            return _UnkeyedDecodingContainer(codingPath: codingPath + [key], container: value, decoder: decoder)
        }
 
        func superDecoder() throws -> Decoder {
            let key = _CodingKey(stringValue: "super")!
            guard let value = container[key.stringValue] else {throw DecodingError.typeMismatch([XMLNode].self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "line: \(#line)"))}
            return _Decoder(codingPath: codingPath + [key], container: value, userInfo: decoder.userInfo, dataDecodingStrategy: decoder.dataDecodingStrategy, dateDecodingStrategy: decoder.dateDecodingStrategy)
        }
 
        func superDecoder(forKey key: Key) throws -> Decoder {
            guard let value = container[key.stringValue] else {throw DecodingError.typeMismatch([XMLNode].self, DecodingError.Context(codingPath: codingPath + [key], debugDescription: "line: \(#line)"))}
            return _Decoder(codingPath: codingPath + [key], container: value, userInfo: decoder.userInfo, dataDecodingStrategy: decoder.dataDecodingStrategy, dateDecodingStrategy: decoder.dateDecodingStrategy)
        }
 
 
    }
 
    private struct _UnkeyedDecodingContainer: UnkeyedDecodingContainer {
        var codingPath: [CodingKey]
        var decoder: _Decoder
 
        var count: Int? {
            return container.count
        }
 
        var isAtEnd: Bool {
            return currentIndex >= container.count
        }
 
        var currentIndex: Int = 0
        var container: [XMLNode]
 
        init(codingPath: [CodingKey], container: [XMLNode], decoder: _Decoder) {
            self.codingPath = codingPath
            self.container = container
            self.decoder = decoder
        }
 
        mutating private func get<T: StringRepresentable>() throws -> T {
            guard let value = container[currentIndex].value.flatMap({T($0)}) else {throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath + [_CodingKey(intValue: currentIndex)!], debugDescription: "line: \(#line)"))}
            currentIndex += 1
            return value
        }

        mutating func decodeNil() throws -> Bool {
            return container[currentIndex].value == nil
        }
 
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            return try get()
        }
 
        mutating func decode(_ type: String.Type) throws -> String {
            return try get()
        }
 
        mutating func decode(_ type: Double.Type) throws -> Double {
            return try get()
        }
 
        mutating func decode(_ type: Float.Type) throws -> Float {
            return try get()
        }
 
        mutating func decode(_ type: Int.Type) throws -> Int {
            return try get()
        }
 
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            return try get()
        }
 
        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            return try get()
        }
 
        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            return try get()
        }
 
        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            return try get()
        }
 
        mutating func decode(_ type: UInt.Type) throws -> UInt {
            return try get()
        }
 
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try get()
        }
 
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try get()
        }
 
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try get()
        }
 
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try get()
        }
 
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            let container = try decoder.decode(type, from: [self.container[currentIndex]], forCodingPath: codingPath + [_CodingKey(intValue: currentIndex)!])
            currentIndex += 1
            return container
        }
 
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            let container = _KeyedDecodingContainer<NestedKey>(codingPath: codingPath + [_CodingKey(intValue: currentIndex)!], container: self.container[currentIndex], decoder: decoder)
            currentIndex += 1
            return KeyedDecodingContainer(container)
        }
 
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let container = _UnkeyedDecodingContainer(codingPath: codingPath + [_CodingKey(intValue: currentIndex)!], container: self.container[currentIndex].values, decoder: decoder)
            currentIndex += 1
            return container
        }
 
        mutating func superDecoder() throws -> Decoder {
            let container = _Decoder(codingPath: codingPath + [_CodingKey(intValue: currentIndex)!], container: [self.container[currentIndex]], userInfo: decoder.userInfo, dataDecodingStrategy: decoder.dataDecodingStrategy, dateDecodingStrategy: decoder.dateDecodingStrategy)
            currentIndex += 1
            return container
        }
 
 
    }
 
    private struct _SingleValueDecodingContainer: SingleValueDecodingContainer {
        var codingPath: [CodingKey]
        var container: XMLNode
        var decoder: _Decoder
 
        private func get<T: StringRepresentable>() throws -> T {
            guard let value = container.value.flatMap({T($0)}) else {throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(codingPath: codingPath, debugDescription: "line: \(#line)"))}
            return value
        }

        func decodeNil() -> Bool {
            return container.value == nil
        }
 
        func decode(_ type: Bool.Type) throws -> Bool {
            return try get()
        }
 
        func decode(_ type: String.Type) throws -> String {
            return try get()
        }
 
        func decode(_ type: Double.Type) throws -> Double {
            return try get()
        }
 
        func decode(_ type: Float.Type) throws -> Float {
            return try get()
        }
 
        func decode(_ type: Int.Type) throws -> Int {
            return try get()
        }
 
        func decode(_ type: Int8.Type) throws -> Int8 {
            return try get()
        }
 
        func decode(_ type: Int16.Type) throws -> Int16 {
            return try get()
        }
 
        func decode(_ type: Int32.Type) throws -> Int32 {
            return try get()
        }
 
        func decode(_ type: Int64.Type) throws -> Int64 {
            return try get()
        }
 
        func decode(_ type: UInt.Type) throws -> UInt {
            return try get()
        }
 
        func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try get()
        }
 
        func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try get()
        }
 
        func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try get()
        }
 
        func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try get()
        }
 
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            return try decoder.decode(type, from: [container], forCodingPath: codingPath)
        }
 
    }
}

