//
//  Socket.swift
//  mysql_driver
//
//  Created by Marius Corega on 24/12/15.
//  Copyright © 2015 Marius Corega. All rights reserved.
//

#if os(Linux)
import Glibc
#else
import Foundation
#endif

import CSocket

extension CSocket {
    
    func readResultOK() throws {
        let data = try readPacket()
        
        switch data[0] {
        case 0x00:
            _ = handleOKPacket(data)
            break
        case 0xfe:
            break
        case 0xff:
            throw handleErrorPacket(data)
        default: break
        }
    }
    
    fileprivate func handleOKPacket(_ data: Data) {
        var n : Int
        
        // 0x00 [1 byte]
        
        // Affected rows [Length Coded Binary]
        
        (_, n) = MySQL.Utils.lenEncInt(( data[1...data.count-1] ))
        
        // Insert id [Length Coded Binary]
        _ = MySQL.Utils.lenEncInt(( data[1+n...data.count-1] ))
    }
    
    func handleErrorPacket(_ data: Data) -> MySQL.Error {
        
        if data[0] != 0xff {
            return MySQL.Error.error(-1, "EOF encountered")
        }
        
        let errno = Data(data[1...3]).value() as UInt16
        var pos = 3
        
        if data[3] == 0x23 {
            pos = 9
        }
        var d1 = Data(data[pos..<data.count])
        d1.append(0)
        let errStr = d1.value() as String
        
        return MySQL.Error.error(Int(errno), errStr)
    }
    
    
    func readUntilEOF() throws {
        var data = try readPacket()
        while data.first != 0xfe {
            
            if data.first == 0xff {
                throw handleErrorPacket(data)
            }
            
            data = try readPacket()
        }
    }
    
    func writeCommandPacketStr(_ cmd: UInt8, q:String) throws {
        
        var data = Data()
        
        data.append(cmd)
        data.append(contentsOf: q.utf8)
        
        try writePacket(&data, packnr: -1)
    }
    
    func writeCommandPacket(_ cmd:UInt8) throws {
        
        var data = Data()
        data.append(cmd)
        
        try writePacket(&data, packnr: -1)
    }
    
    
    func readResultSetHeaderPacket() throws -> Int {
        
        let data = try readPacket()
        
        switch data[0] {
        case 0x00:
            handleOKPacket(data)
            return 0
        case 0xff:
            throw handleErrorPacket(data)
        default:
            break
        }
        
        //column count
        let (num, n) = MySQL.Utils.lenEncInt(data)
        
        guard num != nil else {
            return 0
        }
        
        if (n - data.count) == 0 {
            return Int(num!)
        }
        
        return 0
    }
    
    func readHeader() throws -> (UInt32, Int) {
        
        var bData = try readSync(expectedLength: 3)
        bData.append(0)
        let pn = try readSync(expectedLength: 1).first!
        
        return (bData.value() as UInt32, Int(pn))
    }
    
    func readPacket() throws -> Data {
        let (len, _) = try readHeader()
        // print("packlen \(len)" )
        return try readSync(expectedLength: Int(len))
    }
    
    func writePacket(_ data: inout Data, packnr: Int) throws {
        try writeHeader(UInt32(data.count), pn: UInt8(packnr + 1))
        /*var d = Data(bytes: &data, count: data.count)
        try sendSync(data: &d)*/
        sendAsync(data: &data)
    }
    
    func writeHeader(_ len: UInt32, pn: UInt8) throws {
        var v = len
        var ph = Data.data(&v)
        ph[ph.count-1] = pn
        
        sendAsync(data: &ph)
    }
    
}

