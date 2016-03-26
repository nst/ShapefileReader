//
//  main.swift
//  Shapefile
//
//  Created by nst on 11/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Foundation
import Cocoa

func drawAltitudes() {
    
    let path = "/Users/nst/Projects/ShapefileReader/data/g2g15.dbf"
    
    assert(NSFileManager.defaultManager().fileExistsAtPath(path), "update the path of the dbf file according to your project's location")
    
    let sr = ShapefileReader(path:path)!
    
    let b = ShapefileBitmap(maxWidth: 2000, maxHeight: 2000, bbox:sr.shp!.bbox, color:"SkyBlue")!
    
    b.rectangle(R(10,10,720,40), stroke: "black", fill: "white")
    
    b.setAllowsAntialiasing(true)
    b.text("Mean altitude of the 2328 swiss towns, 2015", P(15,15), font:NSFont(name: "Helvetica", size: 36)!)
    
    b.setAllowsAntialiasing(false)
    b.text("Generated with ShapefileReader https://github.com/nst/ShapefileReader", P(10,b.height-35))
    b.text("Data: Federal Statistical Office (FSO), GEOSTAT: g2g15", P(10,b.height-20))
    
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
    let path = "/Users/nst/Projects/ShapefileReader/data/plz_p1.txt"
    
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
    
    if s.hasPrefix("1") { color = "orchid".color } else
    if s.hasPrefix("2") { color = "forestGreen".color } else
    if s.hasPrefix("3") { color = "chocolate".color } else
    if s.hasPrefix("4") { color = "gold".color } else
    if s.hasPrefix("5") { color = "forestGreen".color } else
    if s.hasPrefix("6") { color = "orchid".color } else
    if s.hasPrefix("7") { color = "forestGreen".color } else
    if s.hasPrefix("8") { color = "gold".color } else
    if s.hasPrefix("9") { color = "orchid".color }
    
    let factor = Double(zip % 1000) / 1000.0
    
    let (r,g,b) = (color.redComponent, color.greenComponent, color.blueComponent)
    
    let r2 : CGFloat = r + (0.8 - r/2.0) * factor*0.8
    let g2 : CGFloat = g + (0.8 - g/2.0) * factor*0.8
    let b2 : CGFloat = b + (0.8 - b/2.0) * factor*0.8

//    let r2 : CGFloat = r + (1.0 - r) * factor*0.85
//    let g2 : CGFloat = g + (1.0 - g) * factor*0.85
//    let b2 : CGFloat = b + (1.0 - b) * factor*0.85

    return NSColor(calibratedRed:r2, green:g2, blue:b2, alpha:1.0)
}

func drawZipLabel(b:BitmapCanvas, _ zip:Int, _ p:CGPoint, _ name:String?=nil) {
    var s = String(zip)
    if let n = name {
        s += " \(n)"
    }
    
    let font = NSFont(name: "Courier", size: 18)!
    
    let textWidth = BitmapCanvas.textWidth(s, font:font)
    
    b.rectangle(R(p.x,p.y,10 + textWidth,26), stroke:"black", fill:colorForZIP(zip))
    b.text(s, P(p.x+5,p.y+5), font:font)
}

func printZipDistribution(zipForTownCode:[Int:(Int,String)]) {
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
}

func drawZIPCodes() {
    
    let zipForTownCode = zipForTownCodeDictionary()
    
    printZipDistribution(zipForTownCode)
    
    // g2g15.shp // communes
    let sr = ShapefileReader(path: "/Users/nst/Projects/ShapefileReader/data/g2g15.shp")!
    
    let b = ShapefileBitmap(maxWidth: 2000, maxHeight: 2000, bbox:sr.shp!.bbox, color:"SkyBlue")!
    
    b.rectangle(R(10,10,665,40), stroke: "black", fill: "white")
    
    b.setAllowsAntialiasing(true)
    b.text("ZIP codes of the 2328 swiss towns, 2015", P(15,15), font:NSFont(name: "Helvetica", size: 36)!)
    
    b.setAllowsAntialiasing(false)
    b.text("Generated with ShapefileReader https://github.com/nst/ShapefileReader", P(10,b.height-35))
    b.text("Data: Federal Statistical Office (FSO), GEOSTAT: g2g15, g1k15", P(10,b.height-20))
    
    b.setAllowsAntialiasing(true)
    
    for (shape, record) in sr.shapeAndRecordGenerator() {
        let n = record[0] as! Int
        
        var color = "black".color
        if let (zip, _) = zipForTownCode[n] {
            //if zip != 1950 { continue }

            color = colorForZIP(zip)
        } else {
            print("-- cannot find zip for town \(record)")
        }
        
        b.shape(shape, color, lineWidth: 0.5)
    }
    
    // g1k15.shp // cantons
    let src = ShapefileReader(path: "/Users/nst/Projects/ShapefileReader/data/g1k15.shp")!
    
    for shape in src.shp.shapeGenerator() {
        b.shape(shape, NSColor.clearColor(), lineWidth: 1.5)
    }
    
    // ZIP labels
    
    drawZipLabel(b, 1000, P(276,841), "Lausanne")
    drawZipLabel(b, 1100, P(166,865))
    drawZipLabel(b, 1200, P(122,1044), "Genève")
    drawZipLabel(b, 1300, P(88,670), "Éclépens")
    drawZipLabel(b, 1400, P(324,673), "Yverdon")
    drawZipLabel(b, 1500, P(395,635))
    drawZipLabel(b, 1600, P(469,778))
    drawZipLabel(b, 1700, P(531,663), "Fribourg")
    drawZipLabel(b, 1800, P(412,865), "Vevey")
    drawZipLabel(b, 1900, P(365,1162))
    drawZipLabel(b, 1950, P(632,1012), "Sion")
    
    drawZipLabel(b, 2000, P(279,460), "Neuchâtel")
    
    drawZipLabel(b, 3000, P(640,535), "Bern")
    drawZipLabel(b, 3700, P(666,726), "Spiez")
    drawZipLabel(b, 3800, P(850,727), "Interlaken")
    drawZipLabel(b, 3900, P(899,974), "Brig")
    
    drawZipLabel(b, 4000, P(641,111), "Basel")

    drawZipLabel(b, 5000, P(920,223), "Aarau")
    
    drawZipLabel(b, 6000, P(1009,503), "Luzern")
    drawZipLabel(b, 6400, P(1131,406), "Zug")
    drawZipLabel(b, 6500, P(1384,1008), "Bellinzona")
    drawZipLabel(b, 6600, P(1096,1031), "Locarno")
    drawZipLabel(b, 6700, P(1262,819))
    drawZipLabel(b, 6800, P(1410,1210))
    drawZipLabel(b, 6900, P(1379,1117), "Lugano")
    
    drawZipLabel(b, 7000, P(1582,595), "Chur")
    drawZipLabel(b, 7500, P(1703,721), "St. Moritz")

    drawZipLabel(b, 8000, P(1128,250), "Zürich")
    drawZipLabel(b, 8200, P(1167,47), "Schaffhausen")
    drawZipLabel(b, 8400, P(1219,185), "Winterthur")
    drawZipLabel(b, 8500, P(1295,144), "Frauenfeld")
    
    drawZipLabel(b, 9000, P(1504,234), "St. Gallen")
    
    b.save("/tmp/switzerland_zip.png", open: true)
}

func drawZIPCodesPDF() {
    let sr = ShapefileReader(path: "/Users/nst/Projects/ShapefileReader/data/g2g15.shp")!
    let view = ShapefileView(maxWidth: 2000, maxHeight: 2000, bbox:sr.shp!.bbox, color:"SkyBlue")!
    let pdfData = view.dataWithPDFInsideRect(view.frame)
    let path = "/tmp/switzerland_zip.pdf"
    let success = pdfData.writeToFile(path, atomically: true)
    if success {
        NSWorkspace.sharedWorkspace().openFile(path)
    }
}

//drawAltitudes()
drawZIPCodes()
//drawZIPCodesPDF()
