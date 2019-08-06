import XCTest
@testable import MySQL

final class MySQLTests: XCTestCase {
    
    struct SampleDataStructure {
        let id: Int
        let name: String
        let dob: Date
    }
    
    var connection: MySQL.Connection!
    
    override func setUp() {
        connection = MySQL.Connection(address: "127.0.0.1", port: 3306, username: "root", password: "", database: "")
        
        /*var v: UInt32 = 3345
        let a1 = [UInt8].UInt24Array(v)
        let a2 = [UInt8](Data.data(&v))
        
        
        print("a1=\(a1)")
        print("a2=\(a2)")*/
    }
    
    /*func testTableFromData() {
        let c = MySQL.table(from: nil as SampleDataStructure?)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
    }*/
    func openedConnection (_ work: (() throws -> Void) ) {
        do {
            try connection.open()
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
    func testSelectQuery () {
        
        openedConnection {
            let m = try connection.query(table: "SELECT * FROM main LIMIT 2")
            
            print(m)
            XCTAssertGreaterThan(m.rows.count, 0)
        }
        
    }
    func testUpdateQuery () {
        
        openedConnection {
            let rows = try connection.query(returningNoData: "UPDATE main SET coins=coins+1 where uuid='Abcd'")
            
            print("rows affected: \(rows)")
            XCTAssertGreaterThan(rows, 0)
        }
        
    }
    func testQueryFail () {
        
        openedConnection {
            do {
                let _ = try connection.query(table: "SELECT * ")
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
        ("testQuery", testSelectQuery),
    ]
}
