//
//  Connection.swift
//  mysql_driver
//
//  Created by Marius Corega on 24/12/15.
//  Copyright © 2015 Marius Corega. All rights reserved.
//

import Foundation
import CSocket

public struct MySQL {
    
    static let maxPackAllowed = 16777215
    
    public typealias MySQLRow = [String?]
    
    struct MySQLHandshake {
        var proto_version:UInt8?
        var server_version:String?
        var conn_id:UInt32?
        var scramble:[UInt8]?
        var cap_flags:UInt16?
        var lang:UInt8?
        var status:UInt16?
        var scramble2:[UInt8]?
    }
    
    public enum Error : Swift.Error {
        case error(Int, String)
        case errorFromQuery(String, Int, String)
        case dataReadingError
        case wrongHandshake
        case tooManyQueries
    }
    
    open class Connectable {
        
        public var maxTriesForQuery = 3
        
        let address: String
        let port: Int32
        
        let user: String
        let password: String?
        
        var dbname:String?
        
        public required init(address: String, port: Int32 = 3306, user:String, password:String? = nil, dbname:String? = nil) {
            
            self.address = address
            self.user = user
            self.password = password
            self.dbname = dbname
            self.port = port
            
        }
        
        public func open() throws {
            
        }
        public func close() throws {
            
        }
        public func query (matrix q: String) throws -> [[String?]] {
            return [[String?]]()
        }
        public func query (_ q:String, row: ([String?]) -> Void) throws {
            row([String?]())
        }
        public func query(returningNoData queries: [String]) throws {
            
        }
    }
    
    open class Connection: Connectable {

        let socket: CSocket
        
        var mysql_Handshake: MySQLHandshake?
        var isConnected = false

        private let sm = DispatchSemaphore(value: 1)
        private let accessors = AtomicValue(0)
        
        public required init(address: String, port: Int32 = 3306, user:String, password:String? = nil, dbname:String? = nil) {
            self.socket = try! CSocket(host: address, port: port)
            self.socket.connectTimeout = 5.0
            self.socket.readTimeout = 5.0

            super.init(address: address, port: port, user: user, password: password, dbname: dbname)
            
        }
        
        func accessorCount () -> Int {
            return accessors.get()
        }
        
        private func access () {
            accessors.set(accessors.get() + 1)
        }
        private func release () {
            accessors.set(accessors.get() - 1)
        }
        
        public override func open() throws {
            try connect()
            try auth()
            try socket.readResultOK()
            isConnected = true
        }
        
        public override func close() throws {
            
            isConnected = false
            
            try socket.writeCommandPacket(MysqlCommands.COM_QUIT)
            socket.close()
        }
        
        private func readHandshake() throws -> MySQL.MySQLHandshake {
            
            var msh = MySQL.MySQLHandshake()
            let data = try socket.readPacket()
            
            var pos = 0
            //print(data)
            msh.proto_version = data[pos]
            pos += 1
            msh.server_version = data[pos..<data.count].value() as String
            pos += msh.server_version!.utf8.count+1
            //         let v1 = UInt32(data[pos...pos+4])
            //         let v2 = data[pos...pos+4].uInt32()
            msh.conn_id = data[pos...pos+4].value()
            
            pos += 4
            msh.scramble = Array(data[pos..<pos+8])
            pos += 8 + 1
            
            msh.cap_flags = Data(data[pos...pos+2]).value() as UInt16
            
            pos += 2
            
            if data.count > pos {
                pos += 1 + 2 + 2 + 1 + 10
                
                let c = Array(data[pos..<pos+12])
                msh.scramble?.append(contentsOf:c)
            }
            
            
            return msh
        }
        
        private func connect() throws {
            try socket.connectSync()
            self.mysql_Handshake = try readHandshake()
        }
        
        private func auth() throws {
            
            var flags:UInt32 = MysqlClientCaps.CLIENT_PROTOCOL_41 |
                MysqlClientCaps.CLIENT_LONG_PASSWORD |
                MysqlClientCaps.CLIENT_TRANSACTIONS |
                MysqlClientCaps.CLIENT_SECURE_CONN |
                
                MysqlClientCaps.CLIENT_LOCAL_FILES |
                MysqlClientCaps.CLIENT_MULTI_STATEMENTS |
                MysqlClientCaps.CLIENT_MULTI_RESULTS
            
            flags &= UInt32(mysql_Handshake!.cap_flags!) | 0xffff0000
            //flags = 238213
            
            if self.dbname != nil {
                flags |= MysqlClientCaps.CLIENT_CONNECT_WITH_DB
            }
            
            var epwd = [UInt8]()
            
            if let password = password {
                
                guard mysql_Handshake != nil, mysql_Handshake!.scramble != nil else {
                    throw MySQL.Error.wrongHandshake
                }

                epwd = MySQL.Utils.encPasswd(password, scramble: self.mysql_Handshake!.scramble!)
            }
            
            //let pay_len = 4 + 4 + 1 + 23 + user!.utf8.count + 1 + 1 + epwd.count + 21 + 1
            
            var arr = Data()
            
            //write flags
            
            //arr.append(contentsOf: [UInt8].UInt32Array(UInt32(flags)))
            var tmpUInt32 = UInt32(flags)
            arr.append(contentsOf: Data.data(&flags))
            
            //write max len packet
            //arr.append(contentsOf:[UInt8].UInt32Array(16777215))
            tmpUInt32 = 16777215
            arr.append(contentsOf: Data.data(&tmpUInt32))
            
            //  socket!.writeUInt8(33) //socket!.writeUInt8(mysql_Handshake!.lang!)
            arr.append(33)
            
            arr.append(contentsOf:[UInt8](repeating:0, count: 23))
            
            //send username
            arr.append(contentsOf: user.utf8)
            arr.append(0)
            
            //send hashed password
            arr.append(UInt8(epwd.count))
            arr.append(contentsOf:epwd)
            
            //db name
            if self.dbname != nil {
                arr.append(contentsOf:self.dbname!.utf8)
            }
            arr.append(0)
            
            arr.append(contentsOf:"mysql_native_password".utf8)
            arr.append(0)
            
            //print(arr)
            
            try socket.writePacket(&arr, packnr: 0)
            
        }
        fileprivate func readColumns(_ count: Int) throws -> [String] {
            
            if count <= 0 {
                return [String]()
            }
            
            var columns = [String](repeating: "", count: count)
            
            var i = 0
            while true {
                
                let data = try socket.readPacket()
                //EOF Packet
                if (data[0] == 0xfe) && ((data.count == 5) || (data.count == 1)) {
                    return columns
                }
                
                //Catalog
                var pos = MySQL.Utils.skipLenEncStr(data)
                
                // Database [len coded string]
                pos += MySQL.Utils.skipLenEncStr((data[pos..<data.count]))
                
                // Table [len coded string]
                
                pos += MySQL.Utils.skipLenEncStr((data[pos..<data.count]))
                
                // Original table [len coded string]
                pos += MySQL.Utils.skipLenEncStr((data[pos..<data.count]))
                
                // Name [len coded string]
                let (name, p) = MySQL.Utils.lenEncStr((data[pos..<data.count]))
                pos += p
                
                var arr = [String?]()
                var j = 0
                while j < data.count {
                    let (str, stride) = MySQL.Utils.lenEncStr(data[j..<data.count])
                    arr.append(str)
                    j += stride
                }
                print("arr=\(arr)")
                
                if name == nil {
                    throw MySQL.Error.dataReadingError
                }
                
                columns[i] = name!
                
                i += 1
            }
            
        }
        
        public override func query (matrix q: String) throws -> [MySQLRow] {
            var matrix = [[String?]]()
            
            try query(q, row: { (row) in
                matrix.append(row)
            })
            
            return matrix
        }
        public override func query (_ q:String, row: (MySQLRow) -> Void) throws {
            
            if let semiColonIndex = q.firstIndex(of: ";"), q[semiColonIndex] != q.last {
                throw MySQL.Error.tooManyQueries
            }
            
            try query(q) { (resLen: Int) in
                
                let columns: [String] = try readColumns(resLen)
                
                if columns.count > 0 {
                    var eof = false
                    
                    while !eof {
                        
                        let r = try readRow(columnCount: columns.count, EOFReached: &eof)
                        if !eof {
                            row(r)
                        }
                        
                    }
                    
                }
                
            }
        }
        
        private func readRow (columnCount: Int, EOFReached: inout Bool) throws -> MySQLRow {
            
            EOFReached = false
            
            let data = try socket.readPacket()
            
            if (data[0] == 0xfe) && (data.count == 5) {
                
                let flags = Data(data[3..<5]).value() as UInt16
                
                if flags & MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS == MysqlServerStatus.SERVER_MORE_RESULTS_EXISTS {
                } else {
                    EOFReached = true
                    // con.hasMoreResults = false
                }
                return [String?]()
            }
            
            if data[0] == 0xff {
                throw socket.handleErrorPacket(data)
            }
            
            var arr = [String?](repeating: nil, count: columnCount)

            var pos = 0
            for i in 0..<columnCount {
                let (name, n) = MySQL.Utils.lenEncStr((data[pos..<data.count]))
                pos += n
                arr[i] = name
            }
            return arr
        }
        public override func query(returningNoData queries: [String]) throws {
            for q in queries where !q.isEmpty {
                try query(q) { (resLen: Int) in
                    if resLen > 0 {
                        try socket.readUntilEOF()
                    }
                }
            }
        }
        public func query(queries: String...) throws {
            return try query(returningNoData: queries)
        }
        
        fileprivate func query(_ q: String, restOfFunction: ((Int) throws -> Void) ) throws {
            
            self.access()
            sm.wait()
            
            defer {
                self.release()
                sm.signal()
            }
            
            var tries = 0
            
            while tries < maxTriesForQuery {
                tries += 1
                
                do {
                    if !isConnected {
                        socket.close()
                        try open()
                    }
                    
                    try socket.writeCommandPacketStr(MysqlCommands.COM_QUERY, q: q)
                    let resLen = try socket.readResultSetHeaderPacket()
                    try restOfFunction(resLen)
                    break
                    
                } catch {
                    
                    if error is CSocket.Error {
                        isConnected = false
                        log("[MySQL] socket error: \(error), reconnecting...")
                        continue
                    } else if let e = error as? MySQL.Error {
                        
                        switch e {
                        case MySQL.Error.error(let code, let str):
                            throw MySQL.Error.errorFromQuery(q, code, str)
                        default:
                            break
                        }
                    }
                    
                    throw error
                }
                
            }
            
            if tries >= maxTriesForQuery {
                
            }
            
        }
        func log (_ txt: Any) {
            print("[MySQL] \(txt)")
        }

    }
    
}
