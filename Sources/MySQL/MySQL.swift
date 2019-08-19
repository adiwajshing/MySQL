//
//  MySQL.swift
//  MySQL
//
//  Created by Adhiraj Singh on 8/6/19.
//

import Foundation
import CSocket

public protocol MySQLConnectable {
    
    var address: String { get }
    var port: Int32 { get }
    var username: String { get }
    var password: String? { get }
    var database: String? { get }
    
    init(address: String, port: Int32, username: String, password: String?, database: String?)
    
    func open() throws
    func close() throws
    func query <T: MySQLRowConvertible> (table q: String) throws -> MySQL.Table<T>
    func query <T: MySQLRowConvertible> (_ q: String, columns: inout MySQL.TableMetaData, row: (T) -> Void) throws
    func query <T: MySQLRowConvertible> (_ q: String, row: (T) -> Void) throws
    func query(returningNoData q: String) throws -> Int
}
public extension MySQLConnectable {
    
    func query <T: MySQLRowConvertible> (_ q: String, row: (T) -> Void) throws {
        var columns = MySQL.TableMetaData()
        try query(q, columns: &columns, row: row)
    }
}

public struct MySQL {
    
    static let maxPackAllowed: UInt32 = 16777215
        
    struct Handshake {
        var proto_version: UInt8?
        var server_version: String?
        var conn_id: UInt32?
        var scramble: Data?
        var cap_flags: UInt16?
        var lang: UInt8?
        var status: UInt16?
    }
    
    public enum Error : Swift.Error {
        case error(Int, String)
        case dataReadingError
        case wrongHandshake
        case tooManyQueries
        case dataConversionFailed
    }
    
    open class Connection: MySQLConnectable {
        
        public var maxTriesForQuery = 3
        
        public let address: String
        public let port: Int32
        public let username: String
        public let password: String?
        public var database: String?
        
        let socket: CSocket
        
        var mysql_Handshake: Handshake?
        var isConnected = false
        
        let sm = DispatchSemaphore(value: 1)
        let accessors = AtomicValue(0)
        
        required public init(address: String, port: Int32, username: String, password: String?, database: String?) {
            self.address = address
            self.port = port
            self.username = username
            self.password = password
            self.database = database
            
            self.socket = try! CSocket(host: address, port: port)
            self.socket.connectTimeout = 5.0
            self.socket.readTimeout = 5.0
        }
        
        public func accessorCount () -> Int {
            return accessors.get()
        }
        
        func access () {
            accessors.work { (v) in
                v += 1
            }
            sm.wait()
        }
        func release () {
            sm.signal()
            accessors.work { (v) in
                v -= 1
            }
        }
        
        func log (_ txt: Any) {
            print("[MySQL] \(txt)")
        }
        
    }
    
}
