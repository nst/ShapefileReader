//
//  BitmapCanvasShapefile.swift
//  Shapefile
//
//  Created by nst on 25/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

class ShapefileBitmap : BitmapCanvas {
    
    var scale = 1.0
    var bbox = (x_min:0.0, y_min:0.0, x_max:0.0, y_max:0.0)
    
    convenience init?(maxWidth:Int, maxHeight:Int, bbox:(x_min:Double, y_min:Double, x_max:Double, y_max:Double), color:ConvertibleToNSColor?) {
        
        let bbox_w = bbox.x_max - bbox.x_min
        let bbox_h = bbox.y_max - bbox.y_min
        
        let isBboxWiderThanThanHeight = bbox_w > bbox_h
        
        let theScale = isBboxWiderThanThanHeight ? (Double(maxWidth) / bbox_w) : (Double(maxHeight) / bbox_h)
        
        print("-- scale: \(theScale)")
        
        let (w,h) = (Int(bbox_w * theScale), Int(bbox_h * theScale))
        
        self.init(w,h,color)
        
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
