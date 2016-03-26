//
//  PDFCanvas.swift
//  Shapefile
//
//  Created by nst on 25/03/16.
//  Copyright © 2016 Nicolas Seriot. All rights reserved.
//

import Cocoa

class CanvasView : NSView {
    
    var cgContext : CGContext!
    
    private func degreesToRadians(x:CGFloat) -> CGFloat {
        return (M_PI * x / 180.0)
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        self.cgContext = unsafeBitCast(NSGraphicsContext.currentContext()!.graphicsPort, CGContextRef.self)
    }
    
    func text(text:String, _ p:NSPoint, rotationRadians:CGFloat?, font : NSFont = NSFont(name: "Monaco", size: 10)!, color color_ : ConvertibleToNSColor = NSColor.blackColor()) {
        
        let color = color_.color
        
        let attr = [
            NSFontAttributeName:font,
            NSForegroundColorAttributeName:color
        ]
        
        CGContextSaveGState(cgContext)
        
        if let radians = rotationRadians {
            CGContextTranslateCTM(cgContext, p.x, p.y);
            CGContextRotateCTM(cgContext, radians)
            CGContextTranslateCTM(cgContext, -p.x, -p.y);
        }
        
        CGContextScaleCTM(cgContext, 1.0, -1.0)
        CGContextTranslateCTM(cgContext, 0.0, -2.0 * p.y - font.pointSize)
        
        text.drawAtPoint(p, withAttributes: attr)
        
        CGContextRestoreGState(cgContext)
    }
    
    func text(text:String, _ p:NSPoint, rotationDegrees degrees:CGFloat = 0.0, font : NSFont = NSFont(name: "Monaco", size: 10)!, color : ConvertibleToNSColor = NSColor.blackColor()) {
        self.text(text, p, rotationRadians: degreesToRadians(degrees), font: font, color: color)
    }
        
    func rectangle(rect:NSRect, stroke stroke_:ConvertibleToNSColor? = NSColor.blackColor(), fill fill_:ConvertibleToNSColor? = nil) {
        
        let stroke = stroke_?.color
        let fill = fill_?.color
        
        CGContextSaveGState(cgContext)
        
        if let existingFillColor = fill {
            existingFillColor.setFill()
            NSBezierPath.fillRect(rect)
        }
        
        if let existingStrokeColor = stroke {
            existingStrokeColor.setStroke()
            NSBezierPath.strokeRect(rect)
        }
        
        CGContextRestoreGState(cgContext)
    }
    
    func polygon(points:[NSPoint], stroke stroke_:ConvertibleToNSColor? = NSColor.blackColor(), lineWidth:CGFloat=1.0, fill fill_:ConvertibleToNSColor? = nil) {
        
        guard points.count >= 3 else {
            assertionFailure("at least 3 points are needed")
            return
        }
        
        CGContextSaveGState(cgContext)
        
        let path = NSBezierPath()
        
        path.moveToPoint(points[0])
        
        for i in 1...points.count-1 {
            path.lineToPoint(points[i])
        }
        
        if let existingFillColor = fill_?.color {
            existingFillColor.setFill()
            path.fill()
        }
        
        path.closePath()
        
        if let existingStrokeColor = stroke_?.color {
            existingStrokeColor.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
        
        CGContextRestoreGState(cgContext)
    }
    
}
