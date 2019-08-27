//
//  Utils.swift
//  mysql_driver
//
//  Created by Marius Corega on 19/12/15.
//  Copyright © 2015 Marius Corega. All rights reserved.
//

import Foundation
import CryptoSwift

extension MySQL {
        
    internal struct Utils {
        
        static func lenEncBin(_ b: Data, stride: inout Int) -> Data? {
            
            guard let num = lenEncInt(b, stride: &stride), num > 0 else {
                return nil
            }
            
            stride += Int(num)
            
            if b.count >= stride {
                let strData = b[stride-Int(num)...stride-1]
                return strData
            }
            
            return Data()
        }
        static func skipLenEncStr (_ data: Data, stride: inout Int) {
            _ = lenEncBin(data, stride: &stride)
        }
        static func lenEncStr(_ b: Data, stride: inout Int) -> String? {
            guard let data = lenEncBin(b, stride: &stride) else {
                return nil
            }
            
            return data.isEmpty ? "" : String(data: data, encoding: .utf8)
        }
        
        static func lenEncInt(_ b: Data, stride: inout Int) -> UInt64? {
            
            let s = stride
            
            if b.count == 0 {
                return nil
            }
            
            var a = 0
            var value: UInt64? = nil
            
            switch b[s] {
                
            case 0xfb: // 251: NULL
                
                a = 1
                break
            case 0xfc: // 252: value of following 2
                
                value = UInt64(b[s+1]) | UInt64(b[s+2])<<8
                a = 3
                break
            case 0xfd:  // 253: value of following 3
                
                value = UInt64(b[s+1]) | UInt64(b[s+2])<<8 | UInt64(b[s+3])<<16
                a = 4
                break
            case 0xfe: // 254: value of following 8

                value = UInt64(b[s+1]) | UInt64(b[s+2])<<8 | UInt64(b[s+3])<<16
                value = value! | UInt64(b[s+4])<<24 | UInt64(b[s+5])<<32
                value = value! | UInt64(b[s+6])<<40
                value = value! | UInt64(b[s+7])<<48 | UInt64(b[s+8])<<56
                
                a = 9
                break
                
            default:
                break
            }
            
            if a == 0 {
                value = UInt64(b[s])
                a = 1
            }
            
            stride += a
            return value
        }
        
        static func encPasswd(_ pwd: String, scramble: Data) -> Data {
            
            if pwd.isEmpty {
                return Data()
            }
            
            let pwdData = [UInt8](pwd.utf8)
            
            let s1 = SHA1().calculate(for: pwdData)
            let s2 = SHA1().calculate(for: s1)
            
            var scr = [UInt8](scramble)
            scr.append(contentsOf: s2)
            
            var s3 = SHA1().calculate(for: scr)
            
            for i in 0..<s3.count {
                s3[i] ^= s1[i]
            }
            
            return Data(s3)
        }
    }
}

public extension Data {

    
    func toObject<T> () -> T {
        
        if T.self == String.self {
            
            var str = ""
            
            var arr = [UInt8](self)
            if arr.last != 0 {
                arr.append(0)
            }
            
            if arr.count > 0 {
                str = String(cString: &arr)
            } else {
                print("string conversion failed")
                str = ""
            }
            
            return str as! T
        }

        return Data(self).withUnsafeBytes { (p) -> T in
            return p.load(as: T.self)
        }
    }

    static func data <T> (_ value: inout T) -> Data {
        return Swift.withUnsafeBytes(of: &value) { (p) -> Data in
            return Data(p)
        }
        
    }
    
}

public extension Date
{
    static let sqlDateTimeFormat = "yyyy-MM-dd HH:mm:ss"
    static let sqlDateFormat = "yyyy-MM-dd"
    static let sqlTimeFormat = "HH:mm:ss"
    static let sqlYearFormat = "yyyy"
    
    static func mySQLFormatter (format: String) -> DateFormatter{
        let dateStringFormatter = DateFormatter()
        dateStringFormatter.dateFormat = format
        dateStringFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateStringFormatter
    }
    
    init(string: String, format: String) {
        if let d = Date.mySQLFormatter(format: format).date(from: string) {
            self.init(timeInterval: 0, since: d)
        } else {
            self.init(timeIntervalSince1970: 0)
        }
    }
    
    func dateTimeString() -> String {
        return Date.mySQLFormatter(format: Date.sqlDateTimeFormat).string(from: self)
    }

}

/*static func mysqlType(_ val:Any) ->String {
 
 //var optional = false
 //var value = val
 
 let m = Mirror(reflecting: val)
 if m.displayStyle == .optional {
 //  let desc = m.description
 //   optional = true
 //value = value!
 
 }
 
 
 switch val {
 case is Int8:
 return "TINYINT"
 case is UInt8:
 return "TINYINT UNSIGNED"
 case is Int16:
 return "SMALLINT"
 case is UInt16:
 return "SMALLINT UNSIGNED"
 case is Int:
 return "INT"
 case is UInt:
 return "INT UNSIGNED"
 case is Int64:
 return "BIGINT"
 case is UInt64:
 return "BIGINT UNSIGNED"
 case is Float:
 return "FLOAT"
 case is Double:
 return "DOUBLE"
 case is String:
 return "MEDIUMTEXT"
 case is Date:
 return "DATETIME"
 case is Data:
 return "LONGBLOB"
 default:
 return ""
 }
 }
 
 static func stringValue(_ val: Any) -> String {
 switch val {
 case is UInt8, is Int8, is Int, is UInt, is UInt16, is Int16, is UInt32, is Int32,
 is UInt64, is Int64, is Float, is Double:
 return "\(val)"
 case is String:
 return "\"\(val)\""
 case is Data:
 let str = escapeData(val as! Data)
 return "\"\(str)\""
 
 default:
 return ""
 }
 }
 fileprivate static func escapeData(_ data: Data) -> String {
 
 var res = Data()
 
 let escapeCharacterMap: [UInt8:String] = [
 0: "\\0",
 10: "\\n",
 92: "\\\\",
 13: "\\r",
 39: "\\'",
 34: "\\\"",
 0x1A: "\\Z"
 ]
 
 for v in data {
 if let escaped = escapeCharacterMap[v]?.utf8 {
 res += escaped
 } else {
 res.append(v)
 }
 }
 
 return String(data: res, encoding: .utf8)!
 }*/
