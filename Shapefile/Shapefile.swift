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

enum ShapeType : Int {
    case NullShape = 0
    case Point = 1
    case PolyLine = 3
    case Polygon = 5
    case Multipoint = 8
    case PointZ = 11
    case PolylineZ = 13
    case PolygonZ = 15
    case MultipointZ = 18
    case PointM = 21
    case PolylineM = 23
    case PolygonM = 25
    case MultipointM = 28
    case Multipatch = 31
    
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
    init(type:ShapeType = .NullShape) {
        self.shapeType = type
    }
    
    var shapeType : ShapeType
    var points : [CGPoint] = []
    var bbox : (x_min:Double, y_min:Double, x_max:Double, y_max:Double) = (0.0,0.0,0.0,0.0)
    var parts : [Int] = []
    var partTypes : [Int] = []
    var z : Double = 0.0
    var m : [Double?] = []
    
    func partPointsGenerator() -> AnyGenerator<[CGPoint]> {
        
        var indices = Array(self.parts)
        indices.append(self.points.count-1)
        
        var i = 0
        
        return anyGenerator {
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
    
    typealias DBFRecord = [AnyObject]
    
    var fileHandle : NSFileHandle!
    var numberOfRecords : Int!
    var fields : [[AnyObject]]!
    var headerLength : Int!
    var recordLengthFromHeader : Int!
    var recordFormat : String!
    
    init?(path:String) {
        guard let f = NSFileHandle(forReadingAtPath: path) else {
            print("-- cannot open .dbf for reading at \(path)")
            return nil
        }
        
        self.fileHandle = f
        self.readHeader()
    }
    
    deinit {
        self.fileHandle.closeFile()
    }
    
    func readHeader() {
        
        guard let f = self.fileHandle else {
            print("Shapefile Reader requires a shapefile or file-like object. (no dbf file found)")
            return
        }
        
        f.seekToFileOffset(0)
        
        let a = unpack("<xxxxIHH20x", f.readDataOfLength(32))
        
        self.numberOfRecords = a[0] as! Int
        self.headerLength = a[1] as! Int
        self.recordLengthFromHeader = a[2] as! Int
        
        let numFields = (headerLength - 33) / 32
        
        self.fields = []
        for _ in 0..<numFields {
            let fieldDesc = unpack("<11sc4xBB14x", f.readDataOfLength(32)) // [name, type CDFLMN, length, count]
            self.fields.append(fieldDesc)
        }
        
        let terminator = unpack("<s", f.readDataOfLength(1))[0] as! String
        assert(terminator == "\r", "unexpected terminator")
        
        self.fields.insert(["DeletionFlag", "C", 1, 0], atIndex: 0)
        
        self.recordFormat = self.buildDBFRecordFormat()
    }
    
    private func recordAtOffset(offset:UInt64) -> DBFRecord {
        
        guard let f = self.fileHandle else {
            print("dbf file is missing")
            return []
        }
        
        f.seekToFileOffset(offset)
        
        guard let recordContents = unpack(self.recordFormat, f.readDataOfLength(self.recordLengthFromHeader)) as? [String] else {
            print("bad record contents")
            return []
        }
        
        let isDeletedRecord = recordContents[0] != " "
        if isDeletedRecord { return [] }
        
        assert(self.fields.count == recordContents.count)
        
        var record : DBFRecord = []
        
        for (fields, value) in Array(Zip2Sequence(self.fields, recordContents)) {
            
            let name = fields[0] as! String
            let type = fields[1] as! String
            //let size = fields[2] as! Int
            let deci = fields[3] as! Int == 1
            
            if name == "DeletionFlag" { continue }
            
            let trimmedValue = value.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            
            if trimmedValue.characters.count == 0 {
                record.append("")
                continue
            }
            
            var v : AnyObject = ""
            
            switch type {
            case "N": // Numeric, Number stored as a string, right justified, and padded with blanks to the width of the field.
                if trimmedValue == "" {
                    v = trimmedValue
                } else if deci || trimmedValue.containsString(".") {
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
        return recordAtIndex(i)
    }
    
    func recordAtIndex(i:Int = 0) -> DBFRecord {
        
        guard let f = self.fileHandle else {
            print("no dbf")
            return []
        }
        
        f.seekToFileOffset(0)
        assert(headerLength != 0)
        let offset = headerLength + (i * recordLengthFromHeader)
        return self.recordAtOffset(UInt64(offset))
    }
    
    func recordGenerator() -> AnyGenerator<DBFRecord> {
        
        guard let n = self.numberOfRecords else {
            return anyGenerator {
                print("-- unknown number of records")
                return nil
            }
        }
        
        var i = 0
        
        return anyGenerator {
            if i >= n { return nil}
            let rec = self.recordAtIndex(i)
            i += 1
            return rec
        }
    }
    
    func allRecords() -> [DBFRecord] {
        
        var records : [DBFRecord] = []
        
        let generator = self.recordGenerator()
        
        while let r = generator.next() {
            records.append(r)
        }
        
        return records
    }
    
    private func buildDBFRecordFormat() -> String {
        let a = self.fields.filter({ $0[2] is Int }).map({ $0[2] })
        let sizes = a as! [Int]
        let totalSize = sizes.reduce(0, combine: +)
        let format = "<" + sizes.map( { String($0) + "s" } ).joinWithSeparator("")
        
        if totalSize != recordLengthFromHeader {
            print("-- error: record size declated in header \(recordLengthFromHeader) != record size declared in fields format \(totalSize)")
            recordLengthFromHeader = totalSize
        }
        
        return format
    }
}

class SHPReader {
    
    var fileHandle : NSFileHandle!
    var shapeType : ShapeType = .NullShape
    var bbox : (x_min:Double, y_min:Double, x_max:Double, y_max:Double) = (0.0,0.0,0.0,0.0) // Xmin, Ymin, Xmax, Ymax
    var elevation : (z_min:Double, z_max:Double) = (0.0, 0.0)
    var measure : (m_min:Double, m_max:Double) = (0.0, 0.0)
    var shpLength : UInt64 = 0
    
    init?(path:String) {
        guard let f = NSFileHandle(forReadingAtPath: path) else {
            print("-- cannot open .shp for reading at \(path)")
            return nil
        }
        
        self.fileHandle = f
        self.readHeader()
    }
    
    deinit {
        self.fileHandle.closeFile()
    }
    
    private func readHeader() {
        
        let f = self.fileHandle
        
        f.seekToFileOffset(24)
        
        let l = unpack(">i", f.readDataOfLength(4))
        self.shpLength = UInt64((l[0] as! Int) * 2)
        
        let a = unpack("<ii", f.readDataOfLength(8))
        //let version = a[0] as! Int
        let shapeTypeInt = a[1] as! Int
        guard let shapeType = ShapeType(rawValue: shapeTypeInt) else {
            assertionFailure("-- unknown shapetype \(shapeTypeInt)")
            return
        }
        self.shapeType = shapeType
        
        let b = unpack("<4d", f.readDataOfLength(32)).map({ $0 as! Double })
        self.bbox = (b[0],b[1],b[2],b[3])
        
        let c = unpack("<4d", f.readDataOfLength(32)).map({ $0 as! Double })
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
    
    func shapeAtOffset(offset:UInt64) -> (next:UInt64, shape:Shape)? {
        
        if offset == shpLength { return nil }
        assert(offset < shpLength, "trying to read shape at offset \(offset), but shpLength is only \(shpLength)")
        
        let record = Shape()
        var nParts : Int = 0
        var nPoints : Int = 0
        
        let f = self.fileHandle
        
        f.seekToFileOffset(offset)
        
        let l = unpack(">2i", f.readDataOfLength(8))
        //let recNum = l[0] as! Int
        let recLength = l[1] as! Int
        
        let next = f.offsetInFile + UInt64((2 * recLength))
        
        let shapeTypeInt = unpack("<i", f.readDataOfLength(4))[0] as! Int
        
        record.shapeType = ShapeType(rawValue: shapeTypeInt)!
        
        if shapeType.hasBoundingBox {
            let a = unpack("<4d", f.readDataOfLength(32)).map({ $0 as! Double })
            record.bbox = (a[0],a[1],a[2],a[3])
        }
        
        if shapeType.hasParts {
            nParts = unpack("<i", f.readDataOfLength(4))[0] as! Int
        }
        
        if shapeType.hasPoints {
            nPoints = unpack("<i", f.readDataOfLength(4))[0] as! Int
        }
        
        if nParts > 0 {
            record.parts = unpack("<\(nParts)i", f.readDataOfLength(nParts * 4)).map({ $0 as! Int })
        }
        
        if shapeType == .Multipatch {
            record.partTypes = unpack("<\(nParts)i", f.readDataOfLength(nParts * 4)).map({ $0 as! Int })
        }
        
        var recPoints : [CGPoint] = []
        for _ in 0..<nPoints {
            let points = unpack("<2d", f.readDataOfLength(16)).map({ $0 as! Double })
            recPoints.append(CGPointMake(CGFloat(points[0]),CGFloat(points[1])))
        }
        record.points = recPoints
        
        if shapeType.hasZValues {
            let a = unpack("<2d", f.readDataOfLength(16)).map({ $0 as! Double })
            let zmin = a[0]
            let zmax = a[1]
            print("zmin: \(zmin), zmax: \(zmax)")
            
            record.z = unpack("<\(nPoints)d", f.readDataOfLength(nPoints * 8)).map({ $0 as! Double })[0]
        }
        
        if shapeType.hasMValues && self.measure.m_min != 0.0 && self.measure.m_max != 0.0 {
            let a = unpack("<2d", f.readDataOfLength(16)).map({ $0 as! Double })
            let mmin = a[0]
            let mmax = a[1]
            print("mmin: \(mmin), mmax: \(mmax)")
            
            // Spec: Any floating point number smaller than –10e38 is considered by a shapefile reader to represent a "no data" value.
            record.m = []
            for m in unpack("<\(nPoints)d", f.readDataOfLength(nPoints * 8)).map({ $0 as! Double }) {
                if m < -10e38 {
                    record.m.append(nil)
                } else {
                    record.m.append(m)
                }
            }
        }
        
        if shapeType.hasSinglePoint {
            let point = unpack("<2d", f.readDataOfLength(16)).map({ $0 as! Double })
            record.points = [CGPointMake(CGFloat(point[0]),CGFloat(point[1]))]
        }
        
        if shapeType.hasSingleZ {
            record.z = unpack("<d", f.readDataOfLength(8)).map({ $0 as! Double })[0]
        }
        
        if shapeType.hasSingleM {
            let a = unpack("<d", f.readDataOfLength(8)).map({ $0 as? Double })
            let m = a[0] < -10e38 ? nil : a[0]
            record.m = [m]
        }
        
        return (next, record)
    }
    
    func shapeGenerator() -> AnyGenerator<Shape> {
        
        var nextIndex : UInt64 = 100
        
        return anyGenerator {
            if let (next, shape) = self.shapeAtOffset(nextIndex) {
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
    
    var fileHandle : NSFileHandle!
    var shapeOffsets : [Int] = []
    
    var numberOfShapes : Int {
        return shapeOffsets.count
    }
    
    init?(path:String) {
        guard let f = NSFileHandle(forReadingAtPath: path) else {
            return nil
        }
        
        self.fileHandle = f
        
        self.shapeOffsets = self.readOffsets()
    }
    
    deinit {
        self.fileHandle?.closeFile()
    }
    
    private func readOffsets() -> [Int] {
        
        guard let f = self.fileHandle else {
            print("no shx")
            return []
        }
        
        // read number of records
        f.seekToFileOffset(24)
        let a = unpack(">i", f.readDataOfLength(4))
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
            f.seekToFileOffset(offset)
            let b = unpack(">i", f.readDataOfLength(4))
            let i = b[0] as! Int
            offsets.append(i * 2)
        }
        
        return offsets
    }
    
    func shapeOffsetAtIndex(i:Int) -> Int? {
        return i < self.shapeOffsets.count ? self.shapeOffsets[i] : nil
    }
}

class ShapefileReader {
    
    var shp : SHPReader!
    var dbf : DBFReader? = nil
    var shx : SHXReader? = nil
    
    var shapeName : String
    
    init?(path:String) {
        
        self.shapeName = (path as NSString).stringByDeletingPathExtension
        
        guard let existingSHPReader = SHPReader(path: "\(shapeName).shp") else {
            return nil
        }
        
        self.shp = existingSHPReader
        self.dbf = DBFReader(path: "\(shapeName).dbf")
        self.shx = SHXReader(path: "\(shapeName).shx")
    }
    
    subscript(i:Int) -> Shape? {
        guard let shx = self.shx else {
            return nil
        }
        
        guard let offset = shx.shapeOffsetAtIndex(i) else { return nil }
        
        if let (_, shape) = self.shp.shapeAtOffset(UInt64(offset)) {
            return shape
        }
        
        return nil
    }
    
    func shapeAndRecordGenerator() -> AnyGenerator<(Shape, DBFReader.DBFRecord)> {
        
        var i = 0
        
        return anyGenerator {
            guard let s = self[i] else { return nil }
            guard let r = self.dbf?[i] else { return nil }
            i += 1
            return (s, r)
        }
    }
    
}
