//
//  Connection.IO.swift
//  MySQL
//
//  Created by Adhiraj Singh on 8/6/19.
//

import Foundation

public extension MySQL.Connection {
    
    func open() throws {
        
        try socket.connectSync()
        self.mysql_Handshake = try readHandshake()
        
        try auth()
        _ = try readResult()
        
        isConnected = true
    }
    
    func close() throws {
        
        isConnected = false
        
        try writeCommandPacket(MySQL.Command.quit, str: nil)
        socket.close()
    }
    
    private func readHandshake() throws -> MySQL.Handshake {
        
        var msh = MySQL.Handshake()
        let data = try readPacket()
        
        var pos = 0
        //print(data)
        msh.proto_version = data[pos]
        pos += 1
        msh.server_version = data[pos..<data.count].toObject() as String
        pos += msh.server_version!.utf8.count+1
        //         let v1 = UInt32(data[pos...pos+4])
        //         let v2 = data[pos...pos+4].uInt32()
        msh.conn_id = data[pos...pos+4].toObject()
        
        pos += 4
        msh.scramble = Data(data[pos..<pos+8])
        pos += 8 + 1
        
        msh.cap_flags = data[pos...pos+2].toObject() as UInt16
        
        pos += 2
        
        if data.count > pos {
            pos += 1 + 2 + 2 + 1 + 10
            msh.scramble?.append(contentsOf: data[pos..<pos+12])
        }
        
        
        return msh
    }

    private func auth() throws {
        
        var flags: MySQL.ClientFlags = [
            .useProtocol41,
            .longPassword,
            .awareOfTransactions,
            .useSecureConnection,
            .useLocalFiles,
            .enableMultiStatements,
            .enableMultiResults
        ]
        let capFlags = MySQL.ClientFlags(rawValue: UInt32(mysql_Handshake!.cap_flags!) | 0xffff0000)
        flags.formIntersection(capFlags)
        
        if self.database != nil {
            flags.formUnion(.connectWithDB)
        }
        
        var epwd = Data()
        
        if let password = password {
            
            guard mysql_Handshake != nil, mysql_Handshake!.scramble != nil else {
                throw MySQL.Error.wrongHandshake
            }
            
            epwd = MySQL.Utils.encPasswd(password, scramble: self.mysql_Handshake!.scramble!)
        }
        
        var arr = Data()
        
        //write flags
        var tmpUInt32 = (flags).rawValue
        arr.append(contentsOf: Data.data(&flags))
        
        //write max len packet
        tmpUInt32 = MySQL.maxPackAllowed
        arr.append(contentsOf: Data.data(&tmpUInt32))
        
        arr.append(33)
        
        arr.append(contentsOf:[UInt8](repeating:0, count: 23))
        
        //send username
        arr.append(contentsOf: username.utf8)
        arr.append(0)
        
        //send hashed password
        arr.append(UInt8(epwd.count))
        arr.append(contentsOf:epwd)
        
        //db name
        if let db = self.database {
            arr.append(contentsOf: db.utf8)
        }
        arr.append(0)
        
        arr.append(contentsOf: "mysql_native_password".utf8)
        arr.append(0)
        
        try writePacket(&arr, packnr: 0)
        
    }
    
    internal func readResult() throws -> UInt64? {
        var data = try readPacket()
        return try readResult(data: &data)
    }
    
    internal func readResult(data: inout Data) throws -> UInt64? {
        
        switch data[0] {
        case 0x00:
            var n = 1
            // Affected rows [Length Coded Binary]
            let num = MySQL.Utils.lenEncInt(data, stride: &n)
            // print("\(num)")
            // Insert id [Length Coded Binary]
            _ = MySQL.Utils.lenEncInt(data, stride: &n)
            
            return num
        case 0xff:
            throw handleErrorPacket(data)
        default:
            break
        }
        
        return nil
    }
    
    internal func handleErrorPacket(_ data: Data) -> MySQL.Error {
        
        if data[0] != 0xff {
            return MySQL.Error.error(-1, "EOF encountered")
        }
        
        let errno = Data(data[1...3]).toObject() as UInt16
        var pos = 3
        
        if data[pos] == 0x23 {
            pos = 9
        }
        
        let errStr: String = data[pos..<data.count].toObject()
        
        return MySQL.Error.error(Int(errno), errStr)
    }
    
    
    internal func readUntilEOF() throws {
        
        var data = try readPacket()
        while data.first != 0xfe {
            
            if data.first == 0xff {
                throw handleErrorPacket(data)
            }
            
            data = try readPacket()
        }
        
    }
    
    internal func writeCommandPacket(_ cmd: MySQL.Command, str: String?) throws {
        
        var data = Data()
        
        data.append(cmd.rawValue)
        if let str = str {
            data.append(contentsOf: str.utf8)
        }
        
        
        try writePacket(&data, packnr: -1)
    }
    
    internal func readResultSetHeaderPacket() throws -> Int {
        
        var data = try readPacket()
        if let num = try readResult(data: &data) {
            return -Int(num) // set the rows affected as a negative number
        }
        
        var l = 0
        let num = MySQL.Utils.lenEncInt(data, stride: &l) //column count
        
        guard let numColumns = num, l == data.count else {
            return 0
        }
        
        return Int(numColumns) // let the number of columns be a positive number
    }
    
    internal func readHeader() throws -> UInt32 {
        
        var bData = try socket.readSync(expectedLength: 4)
        bData[bData.count-1] = 0
        //let pn = try readSync(expectedLength: 1).first!
        
        return bData.toObject()
    }
    
    internal func readPacket() throws -> Data {
        let len = try readHeader()
        return try socket.readSync(expectedLength: Int(len))
    }
    
    internal func writePacket(_ data: inout Data, packnr: Int) throws {
        try writeHeader(UInt32(data.count), pn: UInt8(packnr + 1))
        socket.sendAsync(data: &data)
    }
    
    internal func writeHeader(_ len: UInt32, pn: UInt8) throws {
        var v = len
        var ph = Data.data(&v)
        ph[ph.count-1] = pn
        
        socket.sendAsync(data: &ph)
    }
    
}
