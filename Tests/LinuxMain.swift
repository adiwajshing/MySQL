import XCTest

import MySQLTests

var tests = [XCTestCaseEntry]()
tests += MySQLTests.allTests()
XCTMain(tests)
