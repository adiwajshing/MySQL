//
//  Column+Row+Data.swift
//  CSocket
//
//  Created by Adhiraj Singh on 8/2/19.
//

import Foundation

extension MySQL {
    
    /*public static func table <T> (from: T? = nil) -> TableMetaData {
        let mirror = Mirror(reflecting: T.self)
        
        var columns = [Column]()
        
        print(mirror.children.first)
        for case let (label?, value) in mirror.children {
            print(label, ", ", value)
        }
        
        return columns
    }*/
    
    public class Table: CustomStringConvertible {
        public let columns: TableMetaData
        public let rows: [Row]
        
        public var description: String {
            
            let carr = columns.map { (column) -> String in
                return column.description
            }
            
            let arr = rows.map { (row) -> String in
                return row.description
            }
            var str = "Table {\n"
            str += "columns:\n\(carr.joined(separator: ", "))\n"
            str += "rows:\n\(arr.joined(separator: ",\n"))\n"
            str += "}"
            return str
        }
        
        init (query: String, conn: MySQLConnectable) throws {
            
            var m = [Column]()
            var rows = [Row]()
            
            try conn.query(query, columns: &m, row: { (row) in
                rows.append(row)
            })
            
            self.columns = m
            self.rows = rows
        }
    }
    
    public typealias TableMetaData = [Column]
    
    public class Column: CustomStringConvertible {
        
        let name: String
        let dataType: MySQL.DataType
        let flags: MySQL.FieldFlag
        
        let table: String
        
        public var description: String {
            return "Column(\(name) => \(dataType))"
        }
        
        public init (name: String, dataType: MySQL.DataType, flags: MySQL.FieldFlag) {
            self.name = name
            self.dataType = dataType
            self.flags = flags
            self.table = ""
        }
        
        internal init (_ packet: Data) throws {
            var pos = 0
            MySQL.Utils.skipLenEncStr(packet, stride: &pos)
            MySQL.Utils.skipLenEncStr(packet, stride: &pos) // Database [len coded string]
            
            var name = MySQL.Utils.lenEncStr(packet, stride: &pos) // Table [len coded string]
            if name == nil {
                throw MySQL.Error.dataReadingError
            }
            self.table = name!
            
            MySQL.Utils.skipLenEncStr(packet, stride: &pos) // Original table [len coded string]
            
            name = MySQL.Utils.lenEncStr(packet, stride: &pos) // Name of column
            if name == nil {
                throw MySQL.Error.dataReadingError
            }
            self.name = name!
            
            MySQL.Utils.skipLenEncStr(packet, stride: &pos) // Original name [len coded string]
            pos += 1 + 2 + 4 //Things I haven't bothered about
            
            self.dataType = DataType(rawValue: packet[pos]) ?? DataType.unknown
            pos += 1
            
            let f: UInt16 = Data(packet[pos..<(pos+2)]).toObject()
            
            self.flags = FieldFlag(rawValue: f)
            
        }
    }
    
    public class Row: CustomStringConvertible {
        
        fileprivate let columns: [String: Int]
        fileprivate let arr: [Item]
        
        public var description: String {
            let strArr = arr.map { (item) -> String in
                return item.description
            }
            return "Row (\(strArr.joined(separator: ", ")))"
        }
        
        init(_ packet: Data, columns: [Column]) {
            
            var c = [String: Int]()
            var a = [Item](reserveCapacity: columns.count)
            
            var pos = 0
            for column in columns {
                let name = MySQL.Utils.lenEncStr(packet, stride: &pos)
                let item = Item(name, column: column)
                
                c[column.name] = a.count
                
                a.append(item)
            }
            
            self.columns = c
            self.arr = a
        }
        
        public subscript (_ key: String) -> Item? {
            get {
                if let i = columns[key] {
                    return self[i]
                }
                return nil
            }
        }
        public subscript (_ i: Int) -> Item? {
            get {
                if i >= 0 && i < arr.count {
                    return arr[i]
                }
                return nil
            }
        }
        
    }
    
    public class Item: CustomStringConvertible {
        public let dataType: MySQL.DataType
        public let dataFlags: MySQL.FieldFlag
        
        let value: Any?
        
        public var description: String {
            let d = value == nil ? "NULL" : "\(value!)"
            return "\(d)"
        }
        
        init(_ strValue: String?, column: Column) {
            self.dataType = column.dataType
            self.dataFlags = column.flags
            
            if strValue == nil {
                self.value = nil
            } else {
                switch dataType {
                case .varString, .varChar, .string:
                    self.value = strValue
                    break
                case .dateTime, .timestamp:
                    self.value = Date(string: strValue!, format: Date.sqlDateTimeFormat)
                    break
                case .time:
                    self.value = Date(string: strValue!, format: Date.sqlTimeFormat)
                    break
                case .date:
                    self.value = Date(string: strValue!, format: Date.sqlDateFormat)
                    break
                case .year:
                    self.value = Date(string: strValue!, format: Date.sqlYearFormat)
                    break
                case .long, .longLong:
                    self.value = column.flags.contains(.unsigned) ? UInt64(strValue!) : Int64(strValue!)
                    break
                case .short:
                    self.value = column.flags.contains(.unsigned) ? UInt16(strValue!) : Int16(strValue!)
                    break
                case .tinyInt:
                    self.value = column.flags.contains(.unsigned) ? UInt8(strValue!) : Int8(strValue!)
                    break
                case .double:
                    self.value = Double(strValue!)
                    break
                case .float:
                    self.value = Float32(strValue!)
                    break
                case .int24:
                    self.value = column.flags.contains(.unsigned) ? Int32(strValue!) : Int32(strValue!)
                    break
                case .blob, .longBlob, .tinyBlob, .mediumBlob:
                    self.value = Data( strValue!.utf8 )
                    break
                default:
                    self.value = strValue!
                    break
                }
            }

        }
        
        public func get <T> () -> T? {
            guard let value = value else {
                return nil
            }
            
            if T.self == Bool.self {
                return (value as! UInt8 == 1) as? T
            }
            
            return value as? T
        }

    }
    
}
extension MySQL.Column: Hashable {
    
    public static func == (lhs: MySQL.Column, rhs: MySQL.Column) -> Bool {
        return lhs.name == rhs.name && lhs.dataType == rhs.dataType
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
