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
    
    fileprivate func degreesToRadians(_ x:CGFloat) -> CGFloat {
        return (M_PI * x / 180.0)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        self.cgContext = unsafeBitCast(NSGraphicsContext.current()!.graphicsPort, to: CGContext.self)
    }
    
    func text(_ text:String, _ p:NSPoint, rotationRadians:CGFloat?, font : NSFont = NSFont(name: "Monaco", size: 10)!, color color_ : ConvertibleToNSColor = NSColor.black) {
        
        let color = color_.color
        
        let attr = [
            NSFontAttributeName:font,
            NSForegroundColorAttributeName:color
        ]
        
        cgContext.saveGState()
        
        if let radians = rotationRadians {
            cgContext.translateBy(x: p.x, y: p.y);
            cgContext.rotate(by: radians)
            cgContext.translateBy(x: -p.x, y: -p.y);
        }
        
        cgContext.scaleBy(x: 1.0, y: -1.0)
        cgContext.translateBy(x: 0.0, y: -2.0 * p.y - font.pointSize)
        
        text.draw(at: p, withAttributes: attr)
        
        cgContext.restoreGState()
    }
    
    func text(_ text:String, _ p:NSPoint, rotationDegrees degrees:CGFloat = 0.0, font : NSFont = NSFont(name: "Monaco", size: 10)!, color : ConvertibleToNSColor = NSColor.black) {
        self.text(text, p, rotationRadians: degreesToRadians(degrees), font: font, color: color)
    }
        
    func rectangle(_ rect:NSRect, stroke stroke_:ConvertibleToNSColor? = NSColor.black, fill fill_:ConvertibleToNSColor? = nil) {
        
        let stroke = stroke_?.color
        let fill = fill_?.color
        
        cgContext.saveGState()
        
        if let existingFillColor = fill {
            existingFillColor.setFill()
            NSBezierPath.fill(rect)
        }
        
        if let existingStrokeColor = stroke {
            existingStrokeColor.setStroke()
            NSBezierPath.stroke(rect)
        }
        
        cgContext.restoreGState()
    }
    
    func polygon(_ points:[NSPoint], stroke stroke_:ConvertibleToNSColor? = NSColor.black, lineWidth:CGFloat=1.0, fill fill_:ConvertibleToNSColor? = nil) {
        
        guard points.count >= 3 else {
            assertionFailure("at least 3 points are needed")
            return
        }
        
        cgContext.saveGState()
        
        let path = NSBezierPath()
        
        path.move(to: points[0])
        
        for i in 1...points.count-1 {
            path.line(to: points[i])
        }
        
        if let existingFillColor = fill_?.color {
            existingFillColor.setFill()
            path.fill()
        }
        
        path.close()
        
        if let existingStrokeColor = stroke_?.color {
            existingStrokeColor.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
        
        cgContext.restoreGState()
    }
    
}
