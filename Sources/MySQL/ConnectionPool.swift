//
//  ConnectionPool.swift
//  MySQL
//
//  Created by Adhiraj Singh on 7/28/19.
//

import Foundation

extension MySQL {
    
    open class ConnectionPool<T: MySQL.Connection>: MySQLConnectable {
        
        public let address: String
        public let port: Int32
        public let username: String
        public let password: String?
        public var database: String?
        
        
        public var connections = [T]()
        
        public var initialConnectionCount = 10
        public var connectionsToAdd = 5
        
        public var refreshIdealConnectionPeriodically = true
        public var refreshIntervalSeconds = 0.5
        
        public var passAccessorThreshhold = 4
        public var maxAccessors = 8
        public var maxOpenConnections = 30
        
        private let timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global(qos: .default) )
        
        private var idealConn: T!
        private var sm = DispatchSemaphore(value: 1)
        
        public required init(address: String, port: Int32, username: String, password: String?, database: String?) {
            self.address = address
            self.port = port
            self.username = username
            self.password = password
            self.database = database
        }
        
        public func open() throws {
            if connections.count > 0 {
                return
            }
            
            for _ in 0..<initialConnectionCount {
                let conn = try newConnection()
                connections.append(conn)
            }
            
            idealConn = connections.first!
            
            if refreshIdealConnectionPeriodically {
                let t = Int(refreshIntervalSeconds * 1000.0)
                timer.schedule(deadline: .now(), repeating: .milliseconds(t), leeway: .milliseconds(5))
                timer.setEventHandler(handler: refresh)
                timer.resume()
            }
            
        }
        public func close() throws {
            for connection in connections {
               try connection.close()
            }
            
            connections.removeAll()
        }
        
        private func refresh () {
            _ = computeIdealConnection()
        }
        private func computeIdealConnection () -> T {
            defer {
                sm.signal()
            }
            
            sm.wait()
            
            var conn = connections[0]
            for c in connections {
                
                if c.accessorCount() < passAccessorThreshhold {
                    break
                }
                
                if c.accessorCount() < conn.accessorCount() {
                    conn = c
                }
            }
            
            if conn.accessorCount() > maxAccessors && connections.count < maxOpenConnections {
                
                for _ in 0..<connectionsToAdd {
                    if let cConn = try? newConnection() {
                        connections.append(cConn)
                        conn = cConn
                    }
                }
                
            }
            
            idealConn = conn
            return conn
        }
        public func idealConnection () -> T {
            if !refreshIdealConnectionPeriodically {
                return computeIdealConnection()
            }
            sm.wait()
            let conn = idealConn!
            sm.signal()
            return conn
        }
        
        public func query(table q: String) throws -> MySQL.Table {
            return try idealConnection().query(table: q)
        }
        public func query(_ q: String, columns: inout MySQL.TableMetaData, row: (MySQL.Row) -> Void) throws {
            try idealConnection().query(q, columns: &columns, row: row)
        }

        public func query(returningNoData q: String) throws -> Int {
            return try idealConnection().query(returningNoData: q)
        }
        
        private func newConnection () throws -> T {
            let conn = T.init(address: self.address, port: self.port, username: self.username, password: self.password, database: self.database)
            try conn.open()
            return conn
        }
        
    
    }
    
    
}
