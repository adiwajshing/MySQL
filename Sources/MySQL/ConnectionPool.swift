//
//  ConnectionPool.swift
//  MySQL
//
//  Created by Adhiraj Singh on 7/28/19.
//

import Foundation

extension MySQL {
    
    open class ConnectionPool<T: Connection>: Connectable {
        
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
        
        public override func open() throws {
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
        
        public override func query(matrix q: String) throws -> [[String?]] {
            return try idealConnection().query(matrix: q)
        }
        public override func query(_ q: String, row: ([String?]) -> Void) throws {
            return try idealConnection().query(q, row: row)
        }
        public override func query(returningNoData queries: String...) throws {
            return try idealConnection().query(returningNoData: queries)
        }
        
        private func newConnection () throws -> T {
            let conn = T.init(address: self.address, port: self.port, user: self.user, password: self.password, dbname: self.dbname)
            try conn.open()
            return conn
        }
        
    
    }
    
    
}
