import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width:pixels,height:pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        NSColor.systemBlue.setFill()
        NSBezierPath(roundedRect:NSRect(x:p*0.06,y:p*0.06,width:p*0.88,height:p*0.88),xRadius:p*0.2,yRadius:p*0.2).fill()
        let config = NSImage.SymbolConfiguration(pointSize:p*0.50,weight:.medium)
            .applying(NSImage.SymbolConfiguration(paletteColors:[.white]))
        if let symbol = NSImage(systemSymbolName:"envelope.badge.fill",accessibilityDescription:nil)?.withSymbolConfiguration(config) {
            let ratio = symbol.size.height / symbol.size.width
            let w = p*0.63, h = w*ratio
            symbol.draw(in:NSRect(x:(p-w)/2,y:(p-h)/2,width:w,height:h))
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
        let data = bitmap.representation(using:.png,properties:[:])!
        try data.write(to:folder.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}
