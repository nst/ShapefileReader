//
//  main.swift
//  Shapefile
//
//  Created by nst on 11/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation
import Cocoa

class BitmapCanvasShapefile : BitmapCanvas {
    
    var scale = 1.0
    var bbox = (x_min:0.0, y_min:0.0, x_max:0.0, y_max:0.0)
    
    convenience init?(maxWidth:Int, maxHeight:Int, bbox:(x_min:Double, y_min:Double, x_max:Double, y_max:Double)) {
        
        let bbox_w = bbox.x_max - bbox.x_min
        let bbox_h = bbox.y_max - bbox.y_min
        
        let isBboxWiderThanThanHeight = bbox_w > bbox_h
        
        let theScale = isBboxWiderThanThanHeight ? (Double(maxWidth) / bbox_w) : (Double(maxHeight) / bbox_h)
        
        print("-- scale: \(theScale)")
        
        let (w,h) = (Int(bbox_w * theScale), Int(bbox_h * theScale))
        
        self.init(w,h,"SkyBlue")
        
        self.scale = theScale
        self.bbox = bbox
    }
    
    func shape(shape:Shape, _ color:ConvertibleToNSColor?, lineWidth:CGFloat=1.0) {
        
        CGContextSaveGState(self.cgContext)
        
        // shapefile coordinates start bottom left
        CGContextTranslateCTM(self.cgContext, 0, CGFloat(self.height))
        CGContextScaleCTM(self.cgContext, 1.0, -1.0)
        
        // scale and translate according to bbox
        CGContextScaleCTM(self.cgContext, CGFloat(scale), CGFloat(scale))
        CGContextTranslateCTM(self.cgContext, CGFloat(-self.bbox.x_min), CGFloat(-self.bbox.y_min))
        
        for points in shape.partPointsGenerator() {
            self.polygon(points, lineWidth:lineWidth / CGFloat(scale), fill:color)
        }
        
        CGContextRestoreGState(self.cgContext)
    }
    
    func scaleVertical(rect:CGRect, startColor:ConvertibleToNSColor, stopColor:ConvertibleToNSColor, min:Int, max:Int) {
        // TODO: support horizontal scale
        // TODO: improve generalisation with more options related to graduations
        
        let c1 = startColor.color
        let c2 = stopColor.color
        
        let count = 2
        let locations : [CGFloat] = [ 1.0, 0.0 ]
        let components : [CGFloat] = [
            c1.redComponent, c1.greenComponent, c1.blueComponent, c1.alphaComponent, // start color
            c2.redComponent, c2.greenComponent, c2.blueComponent, c2.alphaComponent // end color
        ]
        
        let gradient = CGGradientCreateWithColorComponents(CGColorSpaceCreateDeviceRGB(), components, locations, count)
        
        CGContextSaveGState(self.cgContext)
        CGContextAddRect(self.cgContext, rect)
        CGContextClip(self.cgContext)
        let startPoint = P(rect.origin.x,rect.origin.y)
        let endPoint = P(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)
        CGContextDrawLinearGradient (self.cgContext, gradient, startPoint, endPoint, [])
        CGContextRestoreGState(self.cgContext)
        
        let delta = max - min
        for value in min..<max {
            if value % 500 != 0 { continue }
            
            let ratio = Double(value - min) / Double(delta)
            let y = rect.origin.y + rect.size.height - ratio * rect.size.height
            
            self.setAllowsAntialiasing(false)
            self.lineHorizontal(P(rect.origin.x, y), width: rect.size.width, "black")
            
            self.setAllowsAntialiasing(true)
            self.text("\(value) m", P(rect.origin.x + rect.size.width + 10, y-10), font:NSFont(name: "Helvetica", size: 24)!)
        }
        
        self.setAllowsAntialiasing(false)
        CGContextStrokeRect(self.cgContext, rect)
    }
}

func drawAltitudes() {
    
    let path = "/Users/nst/Projects/ShapefileReader/data/g1g15.dbf"
    
    assert(NSFileManager.defaultManager().fileExistsAtPath(path), "update the path of the dbf file according to your project's location")
    
    let sr = ShapefileReader(path:path)!
    
    let b = BitmapCanvasShapefile(maxWidth: 2000, maxHeight: 2000, bbox:sr.shp!.bbox)!
    
    b.rectangle(R(10,10,720,40), stroke: "black", fill: "white")
    
    b.setAllowsAntialiasing(true)
    b.text("Mean altitude of the 2328 swiss towns, 2015", P(15,15), font:NSFont(name: "Helvetica", size: 36)!)
    
    b.setAllowsAntialiasing(false)
    b.text("Generated with ShapefileReader https://github.com/nst/ShapefileReader", P(10,b.height-35))
    b.text("Data: Federal Statistical Office (FSO), GEOSTAT: g1g15", P(10,b.height-20))
    
    b.setAllowsAntialiasing(true)
    
    print("-- numberOfRecords:", sr.dbf!.numberOfRecords)
    print("-- numberOfShapes:", sr.shx!.numberOfShapes)
    
    assert(sr.dbf!.numberOfRecords == sr.shx!.numberOfShapes)
    
    let altitudes = sr.dbf!.recordGenerator().map{ $0[15] as! Int }
    let alt_min = altitudes.minElement()!
    let alt_max = altitudes.maxElement()!
    
    /**/
    
    for (shape, record) in sr.shapeAndRecordGenerator() {
        let altitude = record[15] as! Int
        
        let factor = Double(altitude - alt_min) / Double(alt_max - alt_min)
        let color = NSColor(calibratedRed:CGFloat(factor), green:CGFloat(1.0-factor), blue:0.0, alpha:1.0)
        
        b.shape(shape, color, lineWidth: 0.5)
    }
    
    print("-- alt_max: \(alt_max)")
    print("-- alt_min: \(alt_min)")
    
    b.scaleVertical(R(10,70,30,500), startColor:"green", stopColor:"red", min:alt_min, max:alt_max)
    
    b.save("/tmp/switzerland_altitude.png", open: true)
}

func zipForTownCodeDictionary() -> [Int:(Int,String)] {
    // http://www.taed.ch/dl/plz_p1.txt
    let path = "/Users/nst/Desktop/plz_p1.txt"
    
    let s = try! NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
    
    var d : [Int:(Int,String)] = [:]
    
    s.enumerateLinesUsingBlock { (s, stopPtr) -> Void in
        let comps = s.componentsSeparatedByString("\t")
        let zip = Int(String(comps[2]))!
        let name = comps[5]
        let n = Int(String(comps[11]))!
        
        if let _ = d[n] { return }
        
        d[n] = (zip, name)
    }
    
    return d
}

func colorForZIP(zip:Int) -> NSColor {
    
    var color = "black".color
    
    let s = String(zip)
    
    if s.hasPrefix("10") { color = "red".color } else
    if s.hasPrefix("11") { color = "forestGreen".color } else
    if s.hasPrefix("12") { color = "orchid".color } else
    if s.hasPrefix("13") { color = "gold".color } else
    if s.hasPrefix("14") { color = "forestGreen".color } else
    if s.hasPrefix("15") { color = "chocolate".color } else
    if s.hasPrefix("16") { color = "forestGreen".color } else
    if s.hasPrefix("17") { color = "blue".color } else
    if s.hasPrefix("18") { color = "gold".color } else
    if s.hasPrefix("19") { color = "red".color } else
    if s.hasPrefix("2") { color = "gold".color } else
    if s.hasPrefix("37") { color = "orchid".color } else
    if s.hasPrefix("38") { color = "chocolate".color } else
    if s.hasPrefix("39") { color = "forestGreen".color } else
    if s.hasPrefix("3") { color = "darkSlateGray".color } else
    if s.hasPrefix("4") { color = "orchid".color } else
    if s.hasPrefix("5") { color = "chocolate".color } else
    if s.hasPrefix("65") { color = "orchid".color } else
    if s.hasPrefix("66") { color = "blue".color } else
    if s.hasPrefix("67") { color = "gold".color } else
    if s.hasPrefix("68") { color = "chocolate".color } else
    if s.hasPrefix("69") { color = "forestGreen".color } else
    if s.hasPrefix("6") { color = "red".color } else
    if s.hasPrefix("7") { color = "forestGreen".color } else
    if s.hasPrefix("8") { color = "gold".color } else
    if s.hasPrefix("9") { color = "orchid".color }
    
    let divisor =
    s.hasPrefix("1") ||
    s.hasPrefix("37") ||
    s.hasPrefix("38") ||
    s.hasPrefix("39") ||
    s.hasPrefix("65") ||
    s.hasPrefix("66") ||
    s.hasPrefix("67") ||
    s.hasPrefix("68") ||
    s.hasPrefix("69")
    ? 100 : 1000
    
    var factor = Double(zip % divisor) / Double(divisor)
    factor = min(factor, 0.8)
    
    let (r,g,b) = (color.redComponent, color.greenComponent, color.blueComponent)
    
    let r2 : CGFloat = r + (1.0 - r) * factor
    let g2 : CGFloat = g + (1.0 - g) * factor
    let b2 : CGFloat = b + (1.0 - b) * factor
    
    return NSColor(calibratedRed:r2, green:g2, blue:b2, alpha:1.0)
}

func drawZipLabel(b:BitmapCanvas, _ zip:Int, _ p:CGPoint) {
    b.rectangle(R(p.x,p.y,75,32), stroke:"black", fill:colorForZIP(zip))
    b.text(String(zip), P(p.x+10,p.y+5), font:NSFont(name: "Courier", size: 24)!)
}

func drawZIPCodes() {
    
    let zipForTownCode = zipForTownCodeDictionary()
    
    var d : [Int:Int] = [:]
    
    print("--", zipForTownCode[4284])
    
    for i in 1...9 {
        d[i] = 0
    }
    
    for (_,(zip,_)) in zipForTownCode {
        let shortZip = zip / 1000
        d[shortZip]? += 1
    }
    
    let a = d.sort {$1.1 < $0.1}
    
    for t in a {
        print(t)
    }
    
    // g2g15.shp // communes
    let sr = ShapefileReader(path: "/Users/nst/Desktop/ShapefileReader/data/g2g15.shp")!
    
    let b = BitmapCanvasShapefile(maxWidth: 2000, maxHeight: 2000, bbox:sr.shp!.bbox)!
    
    b.rectangle(R(10,10,665,40), stroke: "black", fill: "white")
    
    b.setAllowsAntialiasing(true)
    b.text("ZIP codes of the 2328 swiss towns, 2015", P(15,15), font:NSFont(name: "Helvetica", size: 36)!)
    
    b.setAllowsAntialiasing(false)
    b.text("Generated with ShapefileReader https://github.com/nst/ShapefileReader", P(10,b.height-35))
    b.text("Data: Federal Statistical Office (FSO), GEOSTAT: g2g15, g1k15", P(10,b.height-20))
    
    b.setAllowsAntialiasing(true)
    
    for (shape, record) in sr.shapeAndRecordGenerator() {
        //        print(record)
        let n = record[0] as! Int
        
        var color = "black".color
        if let (zip, _) = zipForTownCode[n] {
            color = colorForZIP(zip)
            
            //            if String(zip).hasPrefix("69") == false { continue }
            
        } else {
            print("-- cannot find zip for town \(record)")
        }
        
        b.shape(shape, color, lineWidth: 0.5)
    }
    
    // g1k15.shp // cantons
    let src = ShapefileReader(path: "/Users/nst/Desktop/ShapefileReader/data/g1k15.shp")!
    
    for shape in src.shp.shapeGenerator() {
        b.shape(shape, NSColor.clearColor(), lineWidth: 1.5)
    }
    
    // ZIP labels
    
    drawZipLabel(b, 1000, P(265,841))
    drawZipLabel(b, 1100, P(166,865))
    drawZipLabel(b, 1200, P(122,1044))
    drawZipLabel(b, 1300, P(88,670))
    drawZipLabel(b, 1400, P(132,617))
    drawZipLabel(b, 1500, P(395,635))
    drawZipLabel(b, 1600, P(469,778))
    drawZipLabel(b, 1700, P(531,663))
    drawZipLabel(b, 1800, P(299,971))
    drawZipLabel(b, 1900, P(365,1162))
    
    drawZipLabel(b, 2000, P(285,414))
    drawZipLabel(b, 3000, P(640,535))
    drawZipLabel(b, 3700, P(676,789))
    drawZipLabel(b, 3800, P(918,745))
    drawZipLabel(b, 3900, P(939,1100))
    
    drawZipLabel(b, 4000, P(641,111))
    drawZipLabel(b, 5000, P(904,97))
    drawZipLabel(b, 6000, P(969,535))
    drawZipLabel(b, 6500, P(1484,964))
    drawZipLabel(b, 6600, P(1062,1024))
    drawZipLabel(b, 6700, P(1262,819))
    drawZipLabel(b, 6800, P(1410,1210))
    drawZipLabel(b, 6900, P(1405,1094))
    
    drawZipLabel(b, 7000, P(1752,513))
    drawZipLabel(b, 8000, P(1293,47))
    drawZipLabel(b, 9000, P(1611,286))
    
    b.save("/tmp/switzerland_zip.png", open: true)
}

drawAltitudes()
drawZIPCodes()
