//
//  ShapefileView.swift
//  Shapefile
//
//  Created by nst on 26/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

class ShapefileView : CanvasView {
    
    var scale = 1.0
    var bbox = (x_min:0.0, y_min:0.0, x_max:0.0, y_max:0.0)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init?(maxWidth:Int, maxHeight:Int, bbox:(x_min:Double, y_min:Double, x_max:Double, y_max:Double), color:ConvertibleToNSColor?) {
        
        self.bbox = bbox
        let bbox_w = bbox.x_max - bbox.x_min
        let bbox_h = bbox.y_max - bbox.y_min
        
        let isBboxWiderThanThanHeight = bbox_w > bbox_h
        
        let maxWidth = 2000
        let maxHeight = 2000
        
        self.scale = isBboxWiderThanThanHeight ? (Double(maxWidth) / bbox_w) : (Double(maxHeight) / bbox_h)
        
        Swift.print("-- scale: \(scale)")
        
        let (w,h) = (bbox_w * scale, bbox_h * scale)
        
        super.init(frame: NSMakeRect(0, 0, CGFloat(w), CGFloat(h)))
    }
    
    override func drawRect(dirtyRect: NSRect) {
        
        super.drawRect(dirtyRect)
        
        let shapefileReader = ShapefileReader(path: "/Users/nst/Projects/ShapefileReader/data/g2g15.shp")!
        
        let context = unsafeBitCast(NSGraphicsContext.currentContext()!.graphicsPort, CGContextRef.self)
        
        CGContextSaveGState(context)
        
        // makes coordinates start upper left
        CGContextTranslateCTM(context, 0, CGFloat(self.bounds.height))
        CGContextScaleCTM(context, 1.0, -1.0)
        
        "skyBlue".color.setFill()
        NSBezierPath.fillRect(dirtyRect)
        
        let zipForTownCode = zipForTownCodeDictionary()
        
        self.rectangle(R(10,10,665,40), stroke: "black", fill: "white")
        
        self.text("ZIP codes of the 2328 swiss towns, 2015", P(15,15), font:NSFont(name: "Helvetica", size: 36)!)
        
        self.text("Generated with ShapefileReader https://github.com/nst/ShapefileReader", P(10,self.bounds.height-35))
        self.text("Data: Federal Statistical Office (FSO), GEOSTAT: g2g15, g1k15", P(10,self.bounds.height-20))
        
        for (shape, record) in shapefileReader.shapeAndRecordGenerator() {
            //print(record)
            let n = record[0] as! Int
            
            var color = "black".color
            if let (zip, _) = zipForTownCode[n] {
                color = colorForZIP(zip)
            } else {
                Swift.print("-- cannot find zip for town \(record)")
            }
            
            self.shape(context, shape, color, lineWidth: 0.5)
        }
        
        // g1k15.shp // cantons
        let src = ShapefileReader(path: "/Users/nst/Projects/ShapefileReader/data/g1k15.shp")!
        
        for shape in src.shp.shapeGenerator() {
            self.shape(context, shape, NSColor.clearColor(), lineWidth: 1.5)
        }
        
        // ZIP labels
        
        drawZipLabel(context, 1000, P(265,841))
        drawZipLabel(context, 1100, P(166,865))
        drawZipLabel(context, 1200, P(122,1044))
        drawZipLabel(context, 1300, P(88,670))
        drawZipLabel(context, 1400, P(132,617))
        drawZipLabel(context, 1500, P(395,635))
        drawZipLabel(context, 1600, P(469,778))
        drawZipLabel(context, 1700, P(531,663))
        drawZipLabel(context, 1800, P(299,971))
        drawZipLabel(context, 1900, P(365,1162))
        
        drawZipLabel(context, 2000, P(285,414))
        drawZipLabel(context, 3000, P(640,535))
        drawZipLabel(context, 3700, P(676,789))
        drawZipLabel(context, 3800, P(918,745))
        drawZipLabel(context, 3900, P(939,1100))
        
        drawZipLabel(context, 4000, P(641,111))
        drawZipLabel(context, 5000, P(904,97))
        drawZipLabel(context, 6000, P(969,535))
        drawZipLabel(context, 6500, P(1484,964))
        drawZipLabel(context, 6600, P(1062,1024))
        drawZipLabel(context, 6700, P(1262,819))
        drawZipLabel(context, 6800, P(1410,1210))
        drawZipLabel(context, 6900, P(1405,1094))
        
        drawZipLabel(context, 7000, P(1752,513))
        drawZipLabel(context, 8000, P(1293,47))
        drawZipLabel(context, 9000, P(1611,286))
        
        CGContextRestoreGState(context)
    }
    
    func shape(context:CGContext?, _ shape:Shape, _ color:ConvertibleToNSColor?, lineWidth:CGFloat=1.0) {
        
        CGContextSaveGState(context)
        
        // shapefile coordinates start bottom left
        CGContextTranslateCTM(context, 0, CGFloat(self.bounds.size.height))
        CGContextScaleCTM(context, 1.0, -1.0)
        
        // scale and translate according to bbox
        CGContextScaleCTM(context, CGFloat(scale), CGFloat(scale))
        CGContextTranslateCTM(context, CGFloat(-self.bbox.x_min), CGFloat(-self.bbox.y_min))
        
        for points in shape.partPointsGenerator() {
            self.polygon(points, lineWidth:lineWidth / CGFloat(scale), fill:color)
        }
        
        CGContextRestoreGState(context)
    }
    
    func drawZipLabel(context:CGContext?, _ zip:Int, _ p:CGPoint) {
        self.rectangle(R(p.x,p.y,75,32), stroke:"black", fill:colorForZIP(zip))
        self.text(String(zip), P(p.x+10,p.y+5), font:NSFont(name: "Courier", size: 24)!)
    }
}
