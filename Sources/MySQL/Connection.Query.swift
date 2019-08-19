//
//  Connection.Query.swift
//  MySQL
//
//  Created by Adhiraj Singh on 8/6/19.
//

import Foundation
import CSocket

public extension MySQL.Connection {
    
    func query <T: MySQLRowConvertible> (table q: String) throws -> MySQL.Table<T> {
        return try MySQL.Table.init(query: q, conn: self)
    }
    
    func query <T: MySQLRowConvertible> (_ q: String, columns: inout MySQL.TableMetaData, row: (T) -> Void) throws {
        
        if let semiColonIndex = q.firstIndex(of: ";"), q[semiColonIndex] != q.last {
            throw MySQL.Error.tooManyQueries
        }
        
        try query(q) { (resLen) in
            
            columns = try readColumns(resLen)
            
            if columns.count > 0 {
                var eof = false
                
                while !eof {
                    
                    if let r = try readRow(columns: columns, EOFReached: &eof), !eof {
                        
                        do {
                            if T.self == MySQL.Row.self {
                                row(r as! T)
                            } else {
                                let t = try T(r)
                                row(t)
                            }
                        } catch {
                            try readUntilEOF()
                            throw error
                        }

                    }
                    
                }
                
            }
            
        }
    }
    func query(returningNoData q: String) throws -> Int {
        var rows = 0
        try query(q) { (resLen: Int) in
            if resLen > 0 {
                try readUntilEOF()
            } else {
                rows = abs(resLen)
            }
        }
        return rows
    }
    
    func query(_ q: String, restOfFunction: ((Int) throws -> Void) ) throws {
        
        self.access()
        
        defer {
            self.release()
        }
        
        var tries = 0
        
        while tries < maxTriesForQuery {
            tries += 1
            
            do {
                if !isConnected {
                    socket.close()
                    try open()
                }
                
                try writeCommandPacket(MySQL.Command.query, str: q)
                let resLen = try readResultSetHeaderPacket()
                try restOfFunction(resLen)
                break
            } catch {
                
                if error is CSocket.Error, tries < maxTriesForQuery {
                    isConnected = false
                    self.log("socket error: \(error), reconnecting...")
                    continue
                }
                
                throw error
            }
            
        }
        
    }
    
    internal func readColumns(_ count: Int) throws -> [MySQL.Column] {
        
        var columns = [MySQL.Column](reserveCapacity: count)
        
        var data = try readPacket()
        for _ in 0..<count {
            let column = try MySQL.Column(data, index: columns.count)
            columns.append(column)
            
            data = try readPacket()
        }
        
        //EOF Packet
        if !isEOFPacket(data: &data) {
            throw MySQL.Error.dataReadingError
        }
        
        return columns
    }
    internal func readRow (columns: [MySQL.Column], EOFReached: inout Bool) throws -> MySQL.Row? {
        
        EOFReached = false
        
        var data = try readPacket()
        
        if isEOFPacket(data: &data) {
            
            let flags: UInt16 = Data(data[3..<5]).toObject()
            
            if flags & MySQL.ServerStatus.MORE_RESULTS_EXISTS != MySQL.ServerStatus.MORE_RESULTS_EXISTS {
                EOFReached = true
            }
            
            return nil
        }
        
        if data[0] == 0xff {
            throw handleErrorPacket(data)
        }
        
        let row = MySQL.Row(data, columns: columns)
        return row
    }
    internal func isEOFPacket (data: inout Data) -> Bool {
        return (data[0] == 0xfe) && (data.count == 5 || data.count == 1)
    }
    
}
