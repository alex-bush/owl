import AppKit

enum OwlIcon {
    static func image(isAwake: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Short feather tufts, a tall body, and feet keep the silhouette birdlike.
            let body = NSBezierPath()
            body.lineWidth = 1.35
            body.lineJoinStyle = .round
            body.move(to: NSPoint(x: 3.3, y: 9.7))
            body.curve(to: NSPoint(x: 4.4, y: 14.1),
                       controlPoint1: NSPoint(x: 3.3, y: 11.9),
                       controlPoint2: NSPoint(x: 3.7, y: 13.3))
            body.line(to: NSPoint(x: 4.3, y: 16.2))
            body.line(to: NSPoint(x: 6.6, y: 15.0))
            body.curve(to: NSPoint(x: 11.4, y: 15.0),
                       controlPoint1: NSPoint(x: 8.0, y: 15.7),
                       controlPoint2: NSPoint(x: 10.0, y: 15.7))
            body.line(to: NSPoint(x: 13.7, y: 16.2))
            body.line(to: NSPoint(x: 13.6, y: 14.1))
            body.curve(to: NSPoint(x: 14.7, y: 9.7),
                       controlPoint1: NSPoint(x: 14.3, y: 13.3),
                       controlPoint2: NSPoint(x: 14.7, y: 11.9))
            body.curve(to: NSPoint(x: 12.6, y: 3.2),
                       controlPoint1: NSPoint(x: 14.7, y: 6.5),
                       controlPoint2: NSPoint(x: 13.8, y: 3.7))
            body.curve(to: NSPoint(x: 5.4, y: 3.2),
                       controlPoint1: NSPoint(x: 10.9, y: 2.5),
                       controlPoint2: NSPoint(x: 7.1, y: 2.5))
            body.curve(to: NSPoint(x: 3.3, y: 9.7),
                       controlPoint1: NSPoint(x: 4.2, y: 3.7),
                       controlPoint2: NSPoint(x: 3.3, y: 6.5))
            body.close()

            let leftEye = NSRect(x: 4.2, y: 8.7, width: 4.3, height: 4.3)
            let rightEye = NSRect(x: 9.5, y: 8.7, width: 4.3, height: 4.3)
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 8.1, y: 8.1))
            beak.line(to: NSPoint(x: 9.9, y: 8.1))
            beak.line(to: NSPoint(x: 9, y: 6.5))
            beak.close()

            if isAwake {
                body.windingRule = .evenOdd
                body.append(NSBezierPath(ovalIn: leftEye))
                body.append(NSBezierPath(ovalIn: rightEye))
                body.append(beak)
                body.fill()

                NSBezierPath(ovalIn: NSRect(x: 5.8, y: 9.9, width: 1.1, height: 1.7)).fill()
                NSBezierPath(ovalIn: NSRect(x: 11.1, y: 9.9, width: 1.1, height: 1.7)).fill()
            } else {
                body.stroke()

                let eyeRings = NSBezierPath()
                eyeRings.lineWidth = 1.05
                eyeRings.appendOval(in: leftEye)
                eyeRings.appendOval(in: rightEye)
                eyeRings.stroke()

                let eyelids = NSBezierPath()
                eyelids.lineWidth = 1.15
                eyelids.lineCapStyle = .round
                eyelids.move(to: NSPoint(x: 5.2, y: 10.5))
                eyelids.curve(to: NSPoint(x: 7.5, y: 10.5),
                              controlPoint1: NSPoint(x: 5.8, y: 9.9),
                              controlPoint2: NSPoint(x: 6.9, y: 9.9))
                eyelids.move(to: NSPoint(x: 10.5, y: 10.5))
                eyelids.curve(to: NSPoint(x: 12.8, y: 10.5),
                              controlPoint1: NSPoint(x: 11.1, y: 9.9),
                              controlPoint2: NSPoint(x: 12.2, y: 9.9))
                eyelids.stroke()
                beak.fill()
            }

            let feet = NSBezierPath()
            feet.lineWidth = 1.15
            feet.lineCapStyle = .round
            feet.move(to: NSPoint(x: 6.7, y: 3.1))
            feet.line(to: NSPoint(x: 6.7, y: 1.5))
            feet.move(to: NSPoint(x: 5.8, y: 1.5))
            feet.line(to: NSPoint(x: 7.6, y: 1.5))
            feet.move(to: NSPoint(x: 11.3, y: 3.1))
            feet.line(to: NSPoint(x: 11.3, y: 1.5))
            feet.move(to: NSPoint(x: 10.4, y: 1.5))
            feet.line(to: NSPoint(x: 12.2, y: 1.5))
            feet.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
