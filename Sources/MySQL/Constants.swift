//
//  Constants.swift
// static let MYsql_driver
//
//  Created by Marius Corega on 18/12/15.
//  Copyright © 2015 Marius Corega. All rights reserved.
//

extension MySQL {
    
    public struct FieldFlag: OptionSet, CustomStringConvertible {
        
        public let rawValue: UInt16
        
        public static let notNull = FieldFlag( rawValue: 0x0001 )
        public static let primaryKey = FieldFlag( rawValue: 0x0002 )
        public static let unique = FieldFlag( rawValue: 0x0004 )
        public static let multipleKeys = FieldFlag( rawValue: 0x0008 )
        public static let blob = FieldFlag( rawValue: 0x0010 )
        public static let unsigned = FieldFlag( rawValue: 0x0020 )
        public static let zeroFill = FieldFlag( rawValue: 0x0040 )
        public static let binary = FieldFlag( rawValue: 0x0080 )
        public static let enumeration = FieldFlag( rawValue: 0x0100 )
        public static let autoIncrement = FieldFlag( rawValue: 0x0200 )
        public static let timestamp = FieldFlag( rawValue: 0x0400 )
        public static let set = FieldFlag( rawValue: 0x0800 )
        
        public var description: String {
            var arr = [String]()
            
            if self.contains(FieldFlag.primaryKey) {
                arr.append("PRIMARY KEY")
            }
            if self.contains(FieldFlag.notNull) {
                arr.append("NOT NULL")
            }
            if self.contains(FieldFlag.unsigned) {
                arr.append("UNSIGNED")
            }
            if self.contains(FieldFlag.binary) {
                arr.append("BINARY")
            }
            
            return "FieldFlag(rawValue: \(rawValue)) [\(arr.joined(separator: ", "))]"
        }
        public init( rawValue: UInt16 ) {
            self.rawValue = rawValue
        }
    }
    
    public enum DataType: UInt8 {
        case unknown = 0xaa //unknown type
        case decimal = 0x00
        case tinyInt = 0x01  // int8, uint8, bool
        case short = 0x02 // int16, uint16
        case long = 0x03 // int32, uint32
        case float = 0x04 // float32
        case double = 0x05 // float64
        case null = 0x06
        case timestamp = 0x07
        case longLong = 0x08 // int64, uint64
        case int24 = 0x09
        case date = 0x0a
        case time = 0x0b
        case dateTime = 0x0c
        case year = 0x0d
        case newDate = 0x0e
        case varChar = 0x0f
        case bit = 0x10
        case newDecimal = 0xf6
        case enumeration = 0xf7
        case set = 0xf8
        case tinyBlob = 0xf9
        case mediumBlob = 0xfa
        case longBlob = 0xfb
        case blob = 0xfc
        case varString = 0xfd
        case string = 0xfe
        case geometry = 0xff
    }
    
    struct ServerStatus {
        static let MORE_RESULTS_EXISTS : UInt16 = 0x0008
    }
    
    struct ClientFlags: OptionSet {
        
        public let rawValue: UInt32
        
        static let longPassword = ClientFlags(rawValue: 0x00000001)   // new more secure passwords
        static let foundRows = ClientFlags(rawValue: 0x00000002)             // Found instead of affected rows
        static let longFlags = ClientFlags(rawValue: 0x00000004)             // Get all column flags
        static let connectWithDB = ClientFlags(rawValue: 0x00000008)            // One can specify db on connect
        static let noSchema = ClientFlags(rawValue: 0x00000010)            // Don't allow database.table.column
        static let canCompressData = ClientFlags(rawValue: 0x00000020)            // Can use compression protocol
        static let isODBC = ClientFlags(rawValue: 0x00000040)            // Odbc client
        static let useLocalFiles = ClientFlags(rawValue: 0x00000080)            // Can use LOAD DATA LOCAL
        static let ignoreSpaces = ClientFlags(rawValue: 0x00000100)            // Ignore spaces before '('
        static let useProtocol41 = ClientFlags(rawValue: 0x00000200)           // New 4.1 protocol
        static let isInteractive = ClientFlags(rawValue: 0x00000400)            // This is an interactive client
        static let useSSL = ClientFlags(rawValue: 0x00000800)            // Switch to SSL after handshake
        static let ignoreSIGPIPE = ClientFlags(rawValue: 0x00001000)            // IGNORE sigpipes
        static let awareOfTransactions = ClientFlags(rawValue: 0x00002000)            // Client knows about transactions
        static let isReserved = ClientFlags(rawValue: 0x00004000)            // Old flag for 4.1 protocol
        static let useSecureConnection = ClientFlags(rawValue: 0x00008000)            // New 4.1 authentication
        static let enableMultiStatements = ClientFlags(rawValue: 0x00010000)            // Enable/disable multi-stmt support
        static let enableMultiResults = ClientFlags(rawValue: 0x00020000)             // Enable/disable multi-results
    }
    
    enum Command: UInt8 {
        case quit = 0x01
        case initDB = 0x02
        case query = 0x03
        case fieldList = 0x04
        case createDB = 0x05
        case dropDB = 0x06
        /*static let COM_REFRESH               : UInt8 = 0x07
        static let COM_SHUTDOWN              : UInt8 = 0x08
        static let COM_STATISTICS            : UInt8 = 0x09
        static let COM_PROCESS_INFO          : UInt8 = 0x0a
        static let COM_CONNECT               : UInt8 = 0x0b
        static let COM_PROCESS_KILL          : UInt8 = 0x0c
        static let COM_DEBUG                 : UInt8 = 0x0d
        static let COM_PING                  : UInt8 = 0x0e
        static let COM_TIME                  : UInt8 = 0x0f
        static let COM_DELAYED_INSERT        : UInt8 = 0x10
        static let COM_CHANGE_USER           : UInt8 = 0x11
        static let COM_BINLOG_DUMP           : UInt8 = 0x12
        static let COM_TABLE_DUMP            : UInt8 = 0x13
        static let COM_CONNECT_OUT           : UInt8 = 0x14
        static let COM_REGISTER_SLAVE        : UInt8 = 0x15
        static let COM_STMT_PREPARE          : UInt8 = 0x16
        static let COM_STMT_EXECUTE          : UInt8 = 0x17
        static let COM_STMT_SEND_LONG_DATA   : UInt8 = 0x18
        static let COM_STMT_CLOSE            : UInt8 = 0x19
        static let COM_STMT_RESET            : UInt8 = 0x1a
        static let COM_SET_OPTION            : UInt8 = 0x1b
        static let COM_STMT_FETCH            : UInt8 = 0x1c*/
    }
}

