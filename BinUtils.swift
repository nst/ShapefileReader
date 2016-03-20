//
//  BinUtils.swift
//  BinUtils
//
//  Created by Nicolas Seriot on 12/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation

extension String {
    subscript (from:Int, to:Int) -> String {
        return (self as NSString).substringWithRange(NSMakeRange(from, to-from))
    }
}

extension NSData {
    convenience init(_ bytesArray:[UInt8]) {
        self.init(bytes: bytesArray, length: bytesArray.count)
    }
    
    func bytesArray() -> [UInt8] {
        return Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(self.bytes), count: self.length))
    }
}

func bytesToType <T> (value: [UInt8], _: T.Type) -> T {
    return value.withUnsafeBufferPointer {
        return UnsafePointer<T>($0.baseAddress).memory
    }
}

func typeToBytes <T> (var value: T) -> [UInt8] {
    return withUnsafePointer(&value) {
        Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(T)))
    }
}

func hexlify(data:NSData) -> String {
    
    // similar to hexlify() in Python's binascii module
    // https://docs.python.org/2/library/binascii.html
    
    let s = NSMutableString(capacity: data.length * 2)
    var byte: UInt8 = 0
    
    for i in 0 ..< data.length {
        data.getBytes(&byte, range: NSMakeRange(i, 1))
        s.appendFormat("%02X", byte)
    }
    
    return s as String
}

func unhexlify(string:String) -> NSData? {
    
    // similar to unhexlify() in Python's binascii module
    // https://docs.python.org/2/library/binascii.html
    
    let s = string.uppercaseString.stringByReplacingOccurrencesOfString(" ", withString: "")
    
    let nonHexCharacterSet = NSCharacterSet(charactersInString: "0123456789ABCDEF").invertedSet
    if let range = s.rangeOfCharacterFromSet(nonHexCharacterSet) {
        print("-- found non hex character at range \(range)")
        return nil
    }
    
    let data = NSMutableData(capacity: s.characters.count / 2)
    
    for i in 0.stride(to:s.characters.count, by:2) {
        let byteString = s[i, i+2]
        let byte = UInt8(byteString.withCString { strtoul($0, nil, 16) })
        data?.appendBytes([byte] as [UInt8], length: 1)
    }
    
    return data
}

func readIntegerType<T>(type:T.Type, bytes:[UInt8], inout loc:Int) -> T {
    let size = sizeof(T)
    let sub = Array(bytes[loc..<(loc+size)])
    loc += size
    return bytesToType(sub, T.self)
}

func readFloatingPointType<T>(type:T.Type, bytes:[UInt8], inout loc:Int, isBigEndian:Bool) -> T {
    let size = sizeof(T)
    let sub = Array(bytes[loc..<(loc+size)])
    loc += size
    let sub_ = isBigEndian ? sub.reverse() : sub
    return bytesToType(sub_, T.self)
}

func unpack(var format:String, _ data:NSData) -> [AnyObject] {
    
    /*
    similar to unpack() in Python's struct module https://docs.python.org/2/library/struct.html but:
    - native sizes '@' are unsupported
    - so the first character is mandatory, must be '=', '<', '>' or '!'
    - native byte order '=' assumes a little-endian system (eg. Intel x86)
    - 'p' and 'P' format are unsupported
    - the format does not have to match with the exact quantity of data provided
    */

    assert(Int(OSHostByteOrder()) == OSLittleEndian, "\(__FILE__) assumes little endian, but host is big endian")
    
    if let firstChar = format.characters.first {
        let s : NSString = String(firstChar)
        let c = s.substringToIndex(1)
        let firstCharOptions = "=<>!"
        assert(firstCharOptions.containsString(c), "format '\(format)' first character must be among '\(firstCharOptions)'")
    }
    
    var isBigEndian = false
    
    var a : [AnyObject] = []
    
    var loc = 0
    
    let bytes = data.bytesArray()
    
    var n = 0 // repeat counter
    
    while format.characters.count > 0 {
        
        let c = format.removeAtIndex(format.startIndex)
        
        if let i = Int(String(c)) where i >= 0 && i <= 9 {
            if n > 0 { n *= 10 }
            n += i
            continue
        }
        
        if c == "s" {
            let length = max(n,1)
            let sub = Array(bytes[loc..<loc+length])
            
            guard let s = NSString(bytes: sub, length: length, encoding: NSWindowsCP1252StringEncoding) else {
                assertionFailure("-- not a string: \(sub)")
                return []
            }

            a.append(s)

            loc += length

            n = 0
            
            continue
        }
        
        for _ in 0..<max(n,1) {
            
            var o : AnyObject?
            
            switch(c) {
                
            case "@":
                assertionFailure("native size is unsupported")
            case "<", "=":
                isBigEndian = false
            case ">", "!":
                isBigEndian = true
            case "c":
                o = NSString(bytes: [bytes[loc]], length: 1, encoding: NSUTF8StringEncoding); loc += 1
            case "b":
                let r = readIntegerType(Int8.self, bytes:bytes, loc:&loc)
                o = Int(r)
            case "B":
                let r = readIntegerType(UInt8.self, bytes:bytes, loc:&loc)
                o = Int(r)
            case "?":
                let r = readIntegerType(Bool.self, bytes:bytes, loc:&loc)
                o = r ? true : false
            case "h":
                let r = readIntegerType(Int16.self, bytes:bytes, loc:&loc)
                o = Int(isBigEndian ? Int16(bigEndian: r) : r)
            case "H":
                let r = readIntegerType(UInt16.self, bytes:bytes, loc:&loc)
                o = Int(isBigEndian ? UInt16(bigEndian: r) : r)
            case "i":
                fallthrough
            case "l":
                let r = readIntegerType(Int32.self, bytes:bytes, loc:&loc)
                o = Int(isBigEndian ? Int32(bigEndian: r) : r)
            case "I":
                fallthrough
            case "L":
                let r = readIntegerType(UInt32.self, bytes:bytes, loc:&loc)
                o = Int(isBigEndian ? UInt32(bigEndian: r) : r)
            case "q":
                let r = readIntegerType(Int64.self, bytes:bytes, loc:&loc)
                o = Int(isBigEndian ? Int64(bigEndian: r) : r)
            case "Q":
                let r = readIntegerType(UInt64.self, bytes:bytes, loc:&loc)
                o = Int(isBigEndian ? UInt64(bigEndian: r) : r)
            case "f":
                let r = readFloatingPointType(Float32.self, bytes:bytes, loc:&loc, isBigEndian:isBigEndian)
                o = Double(r)
            case "d":
                let r = readFloatingPointType(Float64.self, bytes:bytes, loc:&loc, isBigEndian:isBigEndian)
                o = Double(r)
            case "x":
                loc += 1
            case " ":
                ()
            default:
                assertionFailure("-- unsupported format \(c)")
            }
            
            if let o_ = o { a.append(o_) }
        }
        
        n = 0
        
    }
    
    return a
}
