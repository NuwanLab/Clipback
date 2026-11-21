#!/bin/bash
set -e
cd "$(dirname "$0")"
APP="ClipBack.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -o "$APP/Contents/MacOS/ClipBack" main.swift

# Info.plist first, so the app is always a proper menu bar app (no Dock icon)
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>ClipBack</string>
  <key>CFBundleIdentifier</key><string>com.local.clipback</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleName</key><string>ClipBack</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
plutil -lint "$APP/Contents/Info.plist"

# App icon: drawn at build time, so there are no image files to keep in the repo
make_icon() {
  local TMP; TMP="$(mktemp -d)"
  cat > "$TMP/icon.swift" <<'SWIFT'
import AppKit

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: 1024 - y - h, width: w, height: h)   // top-left origin
}
func fill(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: box(x, y, w, h), xRadius: r, yRadius: r).fill()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Gradient rounded square
let bg = NSBezierPath(roundedRect: box(100, 100, 824, 824), xRadius: 190, yRadius: 190)
NSGradient(starting: c(88, 150, 255), ending: c(110, 70, 240))!.draw(in: bg, angle: -90)

// Translucent back sheet (suggests history)
fill(330, 232, 440, 560, 46, NSColor.white.withAlphaComponent(0.47))

// Clipboard body with soft shadow
NSGraphicsContext.saveGraphicsState()
let sh = NSShadow()
sh.shadowColor = c(25, 10, 90, 0.5)
sh.shadowBlurRadius = 40
sh.shadowOffset = NSSize(width: 0, height: -20)
sh.set()
fill(272, 262, 440, 560, 46, .white)
NSGraphicsContext.restoreGraphicsState()

// Text lines
for (i, w) in [300, 300, 220, 300, 160].enumerated() {
    fill(336, CGFloat(430 + i * 66), CGFloat(w), 28, 14, i == 0 ? c(110, 120, 220) : c(190, 200, 235))
}

// Clip
fill(372, 218, 240, 112, 34, c(60, 66, 110))
fill(432, 244, 120, 56, 24, .white)

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
  swiftc -O "$TMP/icon.swift" -o "$TMP/icon"
  "$TMP/icon" "$TMP/AppIcon.png"
  local SET="$TMP/AppIcon.iconset"; mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/AppIcon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$TMP/AppIcon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns"
}
make_icon || echo "Warning: could not generate the app icon, continuing without it."

codesign --force --sign - "$APP"

# Refresh Launch Services so the new icon shows up
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

echo "Built $APP — run: open $APP"