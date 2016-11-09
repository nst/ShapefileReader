//
//  Shapefile.swift
//  Unpack
//
//  Created by nst on 12/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

// References:
// https://www.esri.com/library/whitepapers/pdfs/shapefile.pdf
// https://raw.githubusercontent.com/GeospatialPython/pyshp/master/shapefile.py

import Foundation
import CoreGraphics
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


typealias MapPoint = CGPoint

enum ShapeType : Int {
    case nullShape = 0
    case point = 1
    case polyLine = 3
    case polygon = 5
    case multipoint = 8
    case pointZ = 11
    case polylineZ = 13
    case polygonZ = 15
    case multipointZ = 18
    case pointM = 21
    case polylineM = 23
    case polygonM = 25
    case multipointM = 28
    case multipatch = 31
    
    var hasBoundingBox : Bool {
        return [3,5,8,13,15,18,23,25,28,31].contains(self.rawValue)
    }
    
    var hasParts : Bool {
        return [3,5,13,15,23,25,31].contains(self.rawValue)
    }
    
    var hasPoints : Bool {
        return [3,5,8,13,15,23,25,31].contains(self.rawValue)
    }
    
    var hasZValues : Bool {
        return [13,15,18,31].contains(self.rawValue)
    }
    
    var hasMValues : Bool {
        return [13,15,18,23,25,28,31].contains(self.rawValue)
    }
    
    var hasSinglePoint : Bool {
        return [1,11,21].contains(self.rawValue)
    }
    
    var hasSingleZ : Bool {
        return [11].contains(self.rawValue)
    }
    
    var hasSingleM : Bool {
        return [11,21].contains(self.rawValue)
    }
}

class Shape {
    init(type:ShapeType = .nullShape) {
        self.shapeType = type
    }
    
    var shapeType : ShapeType
    var points : [MapPoint] = []
    var bbox : (x_min:Double, y_min:Double, x_max:Double, y_max:Double) = (0.0,0.0,0.0,0.0)
    var parts : [Int] = []
    var partTypes : [Int] = []
    var z : Double = 0.0
    var m : [Double?] = []
    
    func partPointsGenerator() -> AnyIterator<[MapPoint]> {
        
        var indices = Array(self.parts)
        indices.append(self.points.count-1)
        
        var i = 0
        
        return AnyIterator {
            if self.shapeType.hasParts == false { return nil }
            
            if i == indices.count - 1 { return nil }
            
            let partPoints = Array(self.points[indices[i]..<indices[i+1]])
            
            i += 1
            
            return partPoints
        }
    }
}

class DBFReader {
    // dBase III+ specs http://www.oocities.org/geoff_wass/dBASE/GaryWhite/dBASE/FAQ/qformt.htm#A
    // extended with dBase IV 2.0 'F' type

    enum Errors: Error {
        case cannotReadFile(path:String)
    }
    
    typealias DBFRecord = [Any]
    
    var fileHandle : FileHandle!
    var numberOfRecords : Int!
    var fileType : Int!
    var lastUpdate : String! // YYYY-MM-DD
    var fields : [[AnyObject]]!
    var headerLength : Int!
    var recordLengthFromHeader : Int!
    var recordFormat : String!
    
    init(path:String) throws {
        self.fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        try self.readHeader()
    }
    
    deinit {
        self.fileHandle.closeFile()
    }
    
    func readHeader() throws {
        
        guard let f = self.fileHandle else {
            print("Shapefile Reader requires a shapefile or file-like object. (no dbf file found)")
            return
        }
        
        f.seek(toFileOffset: 0)
        
        let a = try unpack("<BBBBIHH20x", f.readData(ofLength: 32))
        
        self.fileType = a[0] as! Int
        let YY = a[1] as! Int
        let MM = a[2] as! Int
        let DD = a[3] as! Int
        self.lastUpdate = "\(1900+YY)-\(String(format: "%02d", MM))-\(String(format: "%02d", DD))"
        self.numberOfRecords = a[4] as! Int
        self.headerLength = a[5] as! Int
        self.recordLengthFromHeader = a[6] as! Int
        
        print("-- fileType:", fileType)
        print("-- lastUpdate:", lastUpdate)
        print("-- numberOfRecords:", numberOfRecords)
        
        let numFields = (headerLength - 33) / 32
        
        self.fields = []
        for _ in 0..<numFields {
            let fieldDesc = try unpack("<11sc4xBB14x", f.readData(ofLength: 32)) // [name, type CDFLMN, length, count]
            self.fields.append(fieldDesc as [AnyObject])
        }
        
        let terminator = try unpack("<s", f.readData(ofLength: 1))[0] as! String
        assert(terminator == "\r", "unexpected terminator")
        
        self.fields.insert(["DeletionFlag" as AnyObject, "C" as AnyObject, 1 as AnyObject, 0 as AnyObject], at: 0)
        
        self.recordFormat = self.buildDBFRecordFormat()
    }
    
    fileprivate func recordAtOffset(_ offset:UInt64) throws -> DBFRecord {
        
        guard let f = self.fileHandle else {
            print("dbf file is missing")
            return []
        }
        
        f.seek(toFileOffset: offset)
        
        guard let recordContents = try! unpack(self.recordFormat, f.readData(ofLength: self.recordLengthFromHeader)) as? [NSString] else {
            print("bad record contents")
            return []
        }
        
        let isDeletedRecord = recordContents[0] != " "
        if isDeletedRecord { return [] }
        
        assert(self.fields.count == recordContents.count)
        
        var record : DBFRecord = []
        
        for (fields, value) in Array(zip(self.fields, recordContents)) {
            
            let name = fields[0] as! String
            let type = fields[1] as! String
            //let size = fields[2] as! Int
            let deci = fields[3] as! Int == 1
            
            if name == "DeletionFlag" { continue }
            
            let trimmedValue = value.trimmingCharacters(in: CharacterSet.whitespaces)
            
            if trimmedValue.characters.count == 0 {
                record.append("")
                continue
            }
            
            var v : Any = ""
            
            switch type {
            case "N": // Numeric, Number stored as a string, right justified, and padded with blanks to the width of the field.
                if trimmedValue == "" {
                    v = trimmedValue
                } else if deci || trimmedValue.contains(".") {
                    v = Double(trimmedValue)!
                } else {
                    v = Int(trimmedValue)!
                }
            case "F": // Float - since dBASE IV 2.0
                v = Double(trimmedValue)!
            case "D": // Date, 8 bytes - date stored as a string in the format YYYYMMDD.
                v = trimmedValue
            case "C": // Character, All OEM code page characters - padded with blanks to the width of the field.
                v = trimmedValue
            case "L": // Logical, 1 byte - initialized to 0x20 (space) otherwise T or F. ? Y y N n T t F f (? when not initialized).
                v = ["T","t","Y","y"].contains(trimmedValue)
            case "M": // Memo, a string, 10 digits (bytes) representing a .DBT block number. The number is stored as a string, right justified and padded with blanks. All OEM code page characters (stored internally as 10 digits representing a .DBT block number).
                v = trimmedValue
            default:
                assertionFailure("unknown field type: \(type)")
                v = trimmedValue
            }
            
            record.append(v)
        }
        
        return record
    }
    
    subscript(i:Int) -> DBFRecord {
        return try! recordAtIndex(i)
    }
    
    func recordAtIndex(_ i:Int = 0) throws -> DBFRecord {
        
        guard let f = self.fileHandle else {
            print("no dbf")
            return []
        }
        
        f.seek(toFileOffset: 0)
        assert(headerLength != 0)
        let offset = headerLength + (i * recordLengthFromHeader)
        return try self.recordAtOffset(UInt64(offset))
    }
    
    func recordGenerator() throws -> AnyIterator<DBFRecord> {
        
        guard let n = self.numberOfRecords else {
            return AnyIterator {
                print("-- unknown number of records")
                return nil
            }
        }
        
        var i = 0
        
        return AnyIterator {
            if i >= n { return nil}
            let rec = try! self.recordAtIndex(i)
            i += 1
            return rec
        }
    }
    
    func allRecords() throws -> [DBFRecord] {
        
        var records : [DBFRecord] = []
        
        let generator = try self.recordGenerator()
        
        while let r = generator.next() {
            records.append(r)
        }
        
        return records
    }
    
    fileprivate func buildDBFRecordFormat() -> String {
        let a = self.fields.filter({ $0[2] is Int }).map({ $0[2] })
        let sizes = a as! [Int]
        let totalSize = sizes.reduce(0, +)
        let format = "<" + sizes.map( { String($0) + "s" } ).joined(separator: "")
        
        if totalSize != recordLengthFromHeader {
            print("-- error: record size declated in header \(recordLengthFromHeader) != record size declared in fields format \(totalSize)")
            recordLengthFromHeader = totalSize
        }
        
        return format
    }
}

class SHPReader {
    
    var fileHandle : FileHandle!
    var shapeType : ShapeType = .nullShape
    var bbox : (x_min:Double, y_min:Double, x_max:Double, y_max:Double) = (0.0,0.0,0.0,0.0) // Xmin, Ymin, Xmax, Ymax
    var elevation : (z_min:Double, z_max:Double) = (0.0, 0.0)
    var measure : (m_min:Double, m_max:Double) = (0.0, 0.0)
    var shpLength : UInt64 = 0
    
    init(path:String) throws {
        self.fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        try self.readHeader()
    }
    
    deinit {
        self.fileHandle.closeFile()
    }
    
    fileprivate func readHeader() throws {
        
        let f : FileHandle = self.fileHandle
        
        f.seek(toFileOffset: 24)
        
        let l = try unpack(">i", f.readData(ofLength: 4))
        self.shpLength = UInt64((l[0] as! Int) * 2)
        
        let a = try unpack("<ii", f.readData(ofLength: 8))
        //let version = a[0] as! Int
        let shapeTypeInt = a[1] as! Int
        guard let shapeType = ShapeType(rawValue: shapeTypeInt) else {
            assertionFailure("-- unknown shapetype \(shapeTypeInt)")
            return
        }
        self.shapeType = shapeType
        
        let b = try unpack("<4d", f.readData(ofLength: 32)).map({ $0 as! Double })
        self.bbox = (b[0],b[1],b[2],b[3])
        
        let c = try unpack("<4d", f.readData(ofLength: 32)).map({ $0 as! Double })
        self.elevation = (c[0], c[1])
        self.measure = (c[2], c[3])
        
        // don't trust length declared in shp header
        f.seekToEndOfFile()
        let length = f.offsetInFile
        
        if length != self.shpLength {
            print("-- actual shp length \(length) != length in headers \(self.shpLength) -> use the actual one")
            self.shpLength = length
        }
    }
    
    func shapeAtOffset(_ offset:UInt64) throws -> (next:UInt64, shape:Shape)? {
        
        if offset == shpLength { return nil }
        assert(offset < shpLength, "trying to read shape at offset \(offset), but shpLength is only \(shpLength)")
        
        let record = Shape()
        var nParts : Int = 0
        var nPoints : Int = 0
        
        let f : FileHandle = self.fileHandle
        
        f.seek(toFileOffset: offset)
        
        let l = try unpack(">2i", f.readData(ofLength: 8))
        //let recNum = l[0] as! Int
        let recLength = l[1] as! Int
        
        let next = f.offsetInFile + UInt64((2 * recLength))
        
        let shapeTypeInt = try unpack("<i", f.readData(ofLength: 4))[0] as! Int
        
        record.shapeType = ShapeType(rawValue: shapeTypeInt)!
        
        if shapeType.hasBoundingBox {
            let a = try unpack("<4d", f.readData(ofLength: 32)).map({ $0 as! Double })
            record.bbox = (a[0],a[1],a[2],a[3])
        }
        
        if shapeType.hasParts {
            nParts = try unpack("<i", f.readData(ofLength: 4))[0] as! Int
        }
        
        if shapeType.hasPoints {
            nPoints = try unpack("<i", f.readData(ofLength: 4))[0] as! Int
        }
        
        if nParts > 0 {
            record.parts = try unpack("<\(nParts)i", f.readData(ofLength: nParts * 4)).map({ $0 as! Int })
        }
        
        if shapeType == .multipatch {
            record.partTypes = try unpack("<\(nParts)i", f.readData(ofLength: nParts * 4)).map({ $0 as! Int })
        }
        
        var recPoints : [MapPoint] = []
        for _ in 0..<nPoints {
            let points = try unpack("<2d", f.readData(ofLength: 16)).map({ $0 as! Double })
            recPoints.append(CGPoint(x: CGFloat(points[0]),y: CGFloat(points[1])))
        }
        record.points = recPoints
        
        if shapeType.hasZValues {
            let a = try unpack("<2d", f.readData(ofLength: 16)).map({ $0 as! Double })
            let zmin = a[0]
            let zmax = a[1]
            print("zmin: \(zmin), zmax: \(zmax)")
            
            record.z = try unpack("<\(nPoints)d", f.readData(ofLength: nPoints * 8)).map({ $0 as! Double })[0]
        }
        
        if shapeType.hasMValues && self.measure.m_min != 0.0 && self.measure.m_max != 0.0 {
            let a = try unpack("<2d", f.readData(ofLength: 16)).map({ $0 as! Double })
            let mmin = a[0]
            let mmax = a[1]
            print("mmin: \(mmin), mmax: \(mmax)")
            
            // Spec: Any floating point number smaller than –10e38 is considered by a shapefile reader to represent a "no data" value.
            record.m = []
            for m in try unpack("<\(nPoints)d", f.readData(ofLength: nPoints * 8)).map({ $0 as! Double }) {
                if m < -10e38 {
                    record.m.append(nil)
                } else {
                    record.m.append(m)
                }
            }
        }
        
        if shapeType.hasSinglePoint {
            let point = try unpack("<2d", f.readData(ofLength: 16)).map({ $0 as! Double })
            record.points = [CGPoint(x: CGFloat(point[0]),y: CGFloat(point[1]))]
        }
        
        if shapeType.hasSingleZ {
            record.z = try unpack("<d", f.readData(ofLength: 8)).map({ $0 as! Double })[0]
        }
        
        if shapeType.hasSingleM {
            let a = try unpack("<d", f.readData(ofLength: 8)).map({ $0 as? Double })
            let m = a[0] < -10e38 ? nil : a[0]
            record.m = [m]
        }
        
        return (next, record)
    }
    
    func shapeGenerator() -> AnyIterator<Shape> {
        
        var nextIndex : UInt64 = 100
        
        return AnyIterator {
            if let (next, shape) = try! self.shapeAtOffset(nextIndex) {
                nextIndex = next
                return shape
            }
            return nil
        }
    }
    
    func allShapes() -> [Shape] {
        
        var shapes : [Shape] = []
        
        let generator = self.shapeGenerator()
        
        while let s = generator.next() {
            shapes.append(s)
        }
        
        return shapes
    }
}

class SHXReader {
    /*
    The shapefile index contains the same 100-byte header as the .shp file, followed by any number of 8-byte fixed-length records which consist of the following two fields:
    Bytes   Type    Endianness  Usage
    0–3     int32   big     Record offset (in 16-bit words)
    4–7     int32   big     Record length (in 16-bit words)
    https://en.wikipedia.org/wiki/Shapefile
    */
    
    var fileHandle : FileHandle!
    var shapeOffsets : [Int] = []
    
    var numberOfShapes : Int {
        return shapeOffsets.count
    }
    
    init(path:String) throws {
        self.fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        self.shapeOffsets = try self.readOffsets()
    }
    
    deinit {
        self.fileHandle?.closeFile()
    }
    
    fileprivate func readOffsets() throws -> [Int] {
        
        guard let f = self.fileHandle else {
            print("no shx")
            return []
        }
        
        // read number of records
        f.seek(toFileOffset: 24)
        let a = try unpack(">i", f.readData(ofLength: 4))
        let halfLength = a[0] as! Int
        let shxRecordLength = (halfLength * 2) - 100
        var numRecords = shxRecordLength / 8
        
        // measure number of records
        f.seekToEndOfFile()
        let eof = f.offsetInFile
        let lengthWithoutHeaders = eof - 100
        let numRecordsMeasured = Int(lengthWithoutHeaders / 8)
        
        // pick measured number of records if different
        if numRecords != numRecordsMeasured {
            print("-- numRecords \(numRecords) != numRecordsMeasured \(numRecordsMeasured) -> use numRecordsMeasured")
            numRecords = numRecordsMeasured
        }
        
        var offsets : [Int] = []
        
        // read the offsets
        for r in 0..<numRecords {
            let offset = UInt64(100 + 8*r)
            f.seek(toFileOffset: offset)
            let b = try unpack(">i", f.readData(ofLength: 4))
            let i = b[0] as! Int
            offsets.append(i * 2)
        }
        
        return offsets
    }
    
    func shapeOffsetAtIndex(_ i:Int) -> Int? {
        return i < self.shapeOffsets.count ? self.shapeOffsets[i] : nil
    }
}

class ShapefileReader {
    
    var shp : SHPReader!
    var dbf : DBFReader? = nil
    var shx : SHXReader? = nil
    
    var shapeName : String
    
    init(path:String) throws {
        
        self.shapeName = (path as NSString).deletingPathExtension

        self.shp = try SHPReader(path: "\(shapeName).shp")
        self.dbf = try DBFReader(path: "\(shapeName).dbf")
        self.shx = try SHXReader(path: "\(shapeName).shx")
    }
    
    subscript(i:Int) -> Shape? {
        guard let shx = self.shx else {
            return nil
        }
        
        guard let offset = shx.shapeOffsetAtIndex(i) else { return nil }
        
        do {
            if let (_, shape) = try self.shp.shapeAtOffset(UInt64(offset)) {
                return shape
            }
        } catch {
        }

        return nil
}
    
    func shapeAndRecordGenerator() -> AnyIterator<(Shape, DBFReader.DBFRecord)> {
        
        var i = 0
        
        return AnyIterator {
            guard let s = self[i] else { return nil }
            guard let r = self.dbf?[i] else { return nil }
            i += 1
            return (s, r)
        }
    }
    
}
