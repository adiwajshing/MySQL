import XCTest
@testable import MySQL

final class MySQLTests: XCTestCase {
    
    struct SampleDataStructure {
        let id: Int
        let name: String
        let dob: Date
    }
    
    var connection: MySQLConnectable!
    
    
    func openedConnection (_ work: (() throws -> Void) ) {
        
        do {
            
            if connection == nil {
                connection = MySQL.Connection(address: "127.0.0.1", port: 3306, username: "root", password: "Garbagepassword123", database: "default")
                try connection.open()
            }
            
            try work()
        } catch {
            XCTFail("error: \(error)")
        }
    }
    func testOpen () {
        openedConnection {
            print("opened")
        }
    }
    func testCreateTable () {
        openedConnection {
            _ = try connection.query(returningNoData: """
                CREATE TABLE IF NOT EXISTS test_table(
                    test_int INT NOT NULL,
                    test_bool BOOL NOT NULL,
                    test_str CHAR(16) NOT NULL,
                    test_date DATETIME NOT NULL,
                    test_uint INT UNSIGNED NOT NULL
                )
            """)
        }
    }
    func testInsertQuery () {
        openedConnection {
            _ = try connection.query(returningNoData: "INSERT INTO test_table VALUES(1, TRUE, 'Hello bro 2', '2019-08-05 12:32:00', 1)")
        }
    }
    func testSelectQueryBool () {
        
        openedConnection {
            let m: MySQL.Table<Bool> = try connection.query(table: "SELECT test_bool FROM test_table")
            
            print(m.rows)
            XCTAssertGreaterThan(m.rows.count, 0)
        }
        
    }
    func testSelectQueryUInt64 () {
        
        openedConnection {
            let m: MySQL.Table<UInt64> = try connection.query(table: "SELECT test_uint FROM test_table")
            
            print(m.rows)
            XCTAssertGreaterThan(m.rows.count, 0)
        }
        
    }
    func testUpdateQuery () {
        
        openedConnection {
            let rows = try connection.query(returningNoData: "UPDATE test_table SET test_int=test_int+1")
            
            print("rows affected: \(rows)")
            XCTAssertGreaterThan(rows, 0)
        }
        
    }
    func testConcurrentQueries () {
        
        self.measure {
            
            openedConnection {
                let functions = [
                    testSelectQueryBool,
                    testSelectQueryUInt64,
                    testUpdateQuery
                ]
                
                DispatchQueue.concurrentPerform(iterations: 100, execute: { (_) in
                    let f = functions[ Int(arc4random()) % functions.count ]
                    f()
                    
                })
            }
            
        }
        
    }
    func testConcurrentQueriesPool () {
        
        do {
            let pool = MySQL.ConnectionPool(address: "127.0.0.1", port: 3306, username: "root", password: "Garbagepassword123", database: "default")
            pool.refreshIdealConnectionPeriodically = false
            pool.passAccessorThreshhold = 1
            pool.refreshIntervalSeconds = 0.05
            
            connection = pool
            
            try connection.open()
            testConcurrentQueries()
        } catch {
            XCTFail("error: \(error)")
        }
        
    }
    func testQueryFail () {
        
        openedConnection {
            do {
                let _: MySQL.Table<MySQL.Row> = try connection.query(table: "SELECT * ")
                XCTFail("should have got error")
            } catch {
                print("got error: \(error)")
            }
        }
        
    }
    override func tearDown() {
        try? connection.close()
    }

    static var allTests = [
        ("testOpen", testOpen),
    ]
}
