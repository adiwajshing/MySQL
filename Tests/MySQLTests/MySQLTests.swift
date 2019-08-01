import XCTest
@testable import MySQL

final class MySQLTests: XCTestCase {
    
    var connection: MySQL.Connection!
    
    override func setUp() {
        connection = MySQL.Connection(address: "127.0.0.1", port: 3306, user: "root", password: "Garbagepassword123", dbname: "ludobosslocal")
        
        /*var v: UInt32 = 3345
        let a1 = [UInt8].UInt24Array(v)
        let a2 = [UInt8](Data.data(&v))
        
        
        print("a1=\(a1)")
        print("a2=\(a2)")*/
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
    }
    func testOpen () {
        do {
            try connection.open()
        } catch {
            XCTFail("error while opening: \(error)")
        }
    }
    func testQuery () {
        
        do {
            try connection.open()
            let m = try connection.query(matrix: "SELECT * FROM main LIMIT 1")
            print(m)
        } catch {
            XCTFail("error: \(error)")
        }
        
    }
    override func tearDown() {
        try? connection.close()
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
