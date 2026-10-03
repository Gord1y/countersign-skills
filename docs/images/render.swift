import CoreText
import CoreGraphics
import Foundation
import ImageIO

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let sRGB: CGColorSpace = {
  guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
    fail("error: could not create the sRGB color space")
  }
  return space
}()

let designSide: CGFloat = 1024
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileCornerRadius = tileRect.width * 0.2237
let cornerSmoothing: CGFloat = 0.6
let degree = CGFloat.pi / 180
let backgroundTop = color(0x4C4642)
let backgroundBottom = color(0x282421)
let nibFace = color(0xF4EFE8)
let nibInk = color(0x1E1B19)
let accent = color(0xE6B04A)

func gradient(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
  guard
    let gradient = CGGradient(
      colorsSpace: sRGB, colors: stops.map(\.0) as CFArray, locations: stops.map(\.1))
  else {
    fail("error: could not create a gradient")
  }
  return gradient
}

func offset(_ point: CGPoint, _ vector: CGVector, _ distance: CGFloat) -> CGPoint {
  CGPoint(x: point.x + vector.dx * distance, y: point.y + vector.dy * distance)
}

struct CubicSegment {
  let control1: CGPoint
  let control2: CGPoint
  let end: CGPoint
}

struct CornerProfile {
  let reach: CGFloat
  let curves: [CubicSegment]

  init(radius: CGFloat) {
    let arcAngle = 90 * (1 - cornerSmoothing)
    let reach = (1 + cornerSmoothing) * radius
    let arcChord = sin(arcAngle / 2 * degree) * radius * 2.squareRoot()
    let arcLeadLength = radius * tan((90 - arcAngle) / 4 * degree)
    let arcLeadAngle = 45 * cornerSmoothing * degree
    let arcLeadAlong = arcLeadLength * cos(arcLeadAngle)
    let arcLeadAcross = arcLeadLength * sin(arcLeadAngle)
    let secondHandle = (reach - arcChord - arcLeadAlong - arcLeadAcross) / 3
    let firstHandle = 2 * secondHandle
    let arcInset = reach - firstHandle - secondHandle - arcLeadAlong
    let arcStart = CGPoint(x: arcInset, y: arcLeadAcross)
    let arcEnd = CGPoint(x: arcLeadAcross, y: arcInset)
    let arcHandle = 4 / 3 * tan(arcAngle / 4 * degree) * radius
    let entry = CGVector(dx: -arcLeadAlong / arcLeadLength, dy: arcLeadAcross / arcLeadLength)
    let exit = CGVector(dx: -arcLeadAcross / arcLeadLength, dy: arcLeadAlong / arcLeadLength)
    self.reach = reach
    curves = [
      CubicSegment(
        control1: CGPoint(x: reach - firstHandle, y: 0),
        control2: CGPoint(x: reach - firstHandle - secondHandle, y: 0), end: arcStart),
      CubicSegment(
        control1: offset(arcStart, entry, arcHandle), control2: offset(arcEnd, exit, -arcHandle),
        end: arcEnd),
      CubicSegment(
        control1: CGPoint(x: 0, y: reach - firstHandle - secondHandle),
        control2: CGPoint(x: 0, y: reach - firstHandle), end: CGPoint(x: 0, y: reach)),
    ]
  }
}

struct CornerFrame {
  let corner: CGPoint
  let incoming: CGVector
  let outgoing: CGVector

  func point(_ local: CGPoint) -> CGPoint {
    offset(offset(corner, incoming, -local.x), outgoing, local.y)
  }
}

func continuousRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
  let radius = min(cornerRadius, min(rect.width, rect.height) / (2 * (1 + cornerSmoothing)))
  let profile = CornerProfile(radius: radius)
  let frames = [
    CornerFrame(
      corner: CGPoint(x: rect.maxX, y: rect.minY), incoming: CGVector(dx: 1, dy: 0),
      outgoing: CGVector(dx: 0, dy: 1)),
    CornerFrame(
      corner: CGPoint(x: rect.maxX, y: rect.maxY), incoming: CGVector(dx: 0, dy: 1),
      outgoing: CGVector(dx: -1, dy: 0)),
    CornerFrame(
      corner: CGPoint(x: rect.minX, y: rect.maxY), incoming: CGVector(dx: -1, dy: 0),
      outgoing: CGVector(dx: 0, dy: -1)),
    CornerFrame(
      corner: CGPoint(x: rect.minX, y: rect.minY), incoming: CGVector(dx: 0, dy: -1),
      outgoing: CGVector(dx: 1, dy: 0)),
  ]
  let path = CGMutablePath()
  for (index, frame) in frames.enumerated() {
    let start = frame.point(CGPoint(x: profile.reach, y: 0))
    if index == 0 {
      path.move(to: start)
    } else {
      path.addLine(to: start)
    }
    for curve in profile.curves {
      path.addCurve(
        to: frame.point(curve.end), control1: frame.point(curve.control1),
        control2: frame.point(curve.control2))
    }
  }
  path.closeSubpath()
  return path
}

func smoothPath(through points: [CGPoint]) -> CGPath {
  let path = CGMutablePath()
  guard let first = points.first else {
    return path
  }
  path.move(to: first)
  for index in 0..<(points.count - 1) {
    let previous = points[max(index - 1, 0)]
    let start = points[index]
    let end = points[index + 1]
    let next = points[min(index + 2, points.count - 1)]
    path.addCurve(
      to: end,
      control1: CGPoint(
        x: start.x + (end.x - previous.x) / 6, y: start.y + (end.y - previous.y) / 6),
      control2: CGPoint(x: end.x - (next.x - start.x) / 6, y: end.y - (next.y - start.y) / 6))
  }
  return path
}

func polylinePath(_ points: [CGPoint]) -> CGPath {
  let path = CGMutablePath()
  path.addLines(between: points)
  return path
}

struct Canvas {
  let context: CGContext
  let pixels: Int

  var scale: CGFloat { CGFloat(pixels) / designSide }

  var smallSizeBoost: CGFloat { 1 + 0.18 * max(0, log2(128 / CGFloat(pixels))) }

  func weight(_ designWidth: CGFloat) -> CGFloat {
    designWidth * smallSizeBoost
  }

  func withShadow(drop: CGFloat, blur: CGFloat, color shadowColor: CGColor, draw: () -> Void) {
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: -drop * scale), blur: blur * scale, color: shadowColor)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    draw()
    context.endTransparencyLayer()
    context.restoreGState()
  }

  func fill(_ path: CGPath, _ fillColor: CGColor) {
    context.addPath(path)
    context.setFillColor(fillColor)
    context.fillPath()
  }

  func stroke(_ path: CGPath, width: CGFloat, _ strokeColor: CGColor) {
    context.addPath(path)
    context.setLineWidth(width)
    context.setStrokeColor(strokeColor)
    context.strokePath()
  }

  func fillVertically(
    _ path: CGPath, _ fillGradient: CGGradient, from top: CGFloat, to bottom: CGFloat
  ) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(
      fillGradient, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: bottom),
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
  }
}

func drawTile(_ canvas: Canvas) {
  let tile = continuousRoundedRect(tileRect, cornerRadius: tileCornerRadius)
  let context = canvas.context

  canvas.withShadow(drop: 10, blur: 22, color: color(0x000000, alpha: 0.32)) {
    canvas.fill(tile, backgroundBottom)
  }

  canvas.fillVertically(
    tile, gradient([(backgroundTop, 0), (backgroundBottom, 1)]), from: tileRect.minY,
    to: tileRect.maxY)

  context.saveGState()
  context.addPath(tile)
  context.clip()
  let glowCenter = CGPoint(x: tileRect.midX, y: tileRect.minY + 40)
  context.drawRadialGradient(
    gradient([(color(0xFFFFFF, alpha: 0.14), 0), (color(0xFFFFFF, alpha: 0), 1)]),
    startCenter: glowCenter, startRadius: 0, endCenter: glowCenter,
    endRadius: tileRect.width * 0.7, options: [])
  context.addPath(tile)
  context.setLineWidth(10)
  context.replacePathWithStrokedPath()
  context.clip()
  context.drawLinearGradient(
    gradient([
      (color(0xFFFFFF, alpha: 0.30), 0), (color(0xFFFFFF, alpha: 0.04), 0.45),
      (color(0x000000, alpha: 0.0), 0.7), (color(0x000000, alpha: 0.22), 1),
    ]),
    start: CGPoint(x: 0, y: tileRect.minY), end: CGPoint(x: 0, y: tileRect.maxY), options: [])
  context.restoreGState()
}

func nibPath(length: CGFloat, halfWidth: CGFloat) -> CGPath {
  let rightSide: [CubicSegment] = [
    CubicSegment(
      control1: CGPoint(x: 0.16, y: 0.16), control2: CGPoint(x: 1, y: 0.34),
      end: CGPoint(x: 1, y: 0.62)),
    CubicSegment(
      control1: CGPoint(x: 1, y: 0.70), control2: CGPoint(x: 0.84, y: 0.72),
      end: CGPoint(x: 0.78, y: 0.76)),
    CubicSegment(
      control1: CGPoint(x: 0.78, y: 0.84), control2: CGPoint(x: 0.78, y: 0.92),
      end: CGPoint(x: 0.78, y: 1)),
    CubicSegment(
      control1: CGPoint(x: 0.36, y: 1.05), control2: CGPoint(x: -0.36, y: 1.05),
      end: CGPoint(x: -0.78, y: 1)),
  ]
  let mirror = CGAffineTransform(scaleX: -1, y: 1)
  let leftSide = (0..<(rightSide.count - 1)).reversed().map { index in
    let start = index == 0 ? CGPoint.zero : rightSide[index - 1].end
    return CubicSegment(
      control1: rightSide[index].control2.applying(mirror),
      control2: rightSide[index].control1.applying(mirror), end: start.applying(mirror))
  }
  let size = CGAffineTransform(scaleX: halfWidth, y: length)
  let path = CGMutablePath()
  path.move(to: .zero)
  for curve in rightSide + leftSide {
    path.addCurve(
      to: curve.end.applying(size), control1: curve.control1.applying(size),
      control2: curve.control2.applying(size))
  }
  path.closeSubpath()
  return path
}

let cardBack = color(0xC9C1B6)
let cardMiddle = color(0xDDD6CC)
let lineInk = color(0x1E1B19, alpha: 0.2)
let titleInk = color(0x1E1B19, alpha: 0.55)

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func bar(_ canvas: Canvas, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, _ ink: CGColor) {
  let thickness = canvas.weight(height)
  canvas.fill(
    roundedRect(
      CGRect(x: x, y: y - thickness / 2, width: width, height: thickness), thickness / 2), ink)
}

let countersignTip = CGPoint(x: 500, y: 640)
let countersignSignature = [
  CGPoint(x: 236, y: 690), CGPoint(x: 290, y: 596), CGPoint(x: 326, y: 686),
  CGPoint(x: 378, y: 624), CGPoint(x: 420, y: 684), countersignTip,
]

func drawNib(_ canvas: Canvas, tip: CGPoint, length: CGFloat, halfWidth: CGFloat) {
  let context = canvas.context
  let breather = CGPoint(x: 0, y: 0.52 * length)
  let placement = CGAffineTransform(translationX: tip.x, y: tip.y).rotated(by: -135 * degree)
  let placedNib = CGMutablePath()
  placedNib.addPath(nibPath(length: length, halfWidth: halfWidth), transform: placement)
  canvas.withShadow(drop: 10, blur: 24, color: color(0x000000, alpha: 0.45)) {
    canvas.fill(placedNib, nibFace)
  }
  context.saveGState()
  context.addPath(placedNib)
  context.clip()
  context.concatenate(placement)
  canvas.fill(
    CGPath(
      rect: CGRect(x: -2 * halfWidth, y: -20, width: 2 * halfWidth, height: 1.2 * length),
      transform: nil), color(0x000000, alpha: 0.13))
  canvas.stroke(polylinePath([CGPoint(x: 0, y: 4), breather]), width: canvas.weight(14), nibInk)
  let holeRadius = canvas.weight(26)
  canvas.fill(
    CGPath(
      ellipseIn: CGRect(
        x: breather.x - holeRadius, y: breather.y - holeRadius, width: 2 * holeRadius,
        height: 2 * holeRadius), transform: nil), nibInk)
  context.restoreGState()
}

func drawSkillCards(_ canvas: Canvas) {
  let context = canvas.context
  let pivot = CGPoint(x: 340, y: 532)
  let size = CGSize(width: 180, height: 236)
  for (rotation, fill) in [(-16.0, cardBack), (-3.0, cardMiddle), (10.0, nibFace)] {
    context.saveGState()
    context.translateBy(x: pivot.x, y: pivot.y)
    context.rotate(by: CGFloat(rotation) * degree)
    let rect = CGRect(x: -size.width / 2, y: -size.height, width: size.width, height: size.height)
    let path = roundedRect(rect, 24)
    canvas.withShadow(drop: 8, blur: 20, color: color(0x000000, alpha: 0.38)) {
      canvas.fill(path, fill)
    }
    context.saveGState()
    context.addPath(path)
    context.clip()
    for (index, fraction) in [0.55, 0.9, 0.75, 0.85].enumerated() {
      let isTitle = index == 0
      bar(
        canvas, x: rect.minX + 28, y: rect.minY + 48 + CGFloat(index) * 38,
        width: (size.width - 56) * CGFloat(fraction), height: isTitle ? 21 : 15,
        isTitle ? titleInk : lineInk)
    }
    context.restoreGState()
    context.restoreGState()
  }
}

func drawArtwork(_ canvas: Canvas) {
  let context = canvas.context
  context.saveGState()
  context.translateBy(x: -20, y: 8)
  drawSkillCards(canvas)
  canvas.stroke(smoothPath(through: countersignSignature), width: canvas.weight(44), accent)
  drawNib(canvas, tip: countersignTip, length: 390, halfWidth: 112)
  context.restoreGState()
}

func makeContext(width: Int, height: Int) -> CGContext {
  guard
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else {
    fail("error: could not create a \(width)x\(height) drawing context")
  }
  return context
}

func renderIcon(pixels: Int) -> CGImage {
  let context = makeContext(width: pixels, height: pixels)
  let canvas = Canvas(context: context, pixels: pixels)
  context.translateBy(x: 0, y: CGFloat(pixels))
  context.scaleBy(x: canvas.scale, y: -canvas.scale)
  context.setLineCap(.round)
  context.setLineJoin(.round)
  drawTile(canvas)
  drawArtwork(canvas)
  guard let image = context.makeImage() else {
    fail("error: could not render the icon at \(pixels) px")
  }
  return image
}

func write(_ image: CGImage, to path: String, type: String = "public.png") {
  let url = URL(fileURLWithPath: path)
  guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil)
  else {
    fail("error: could not create \(path)")
  }
  let options = [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
  CGImageDestinationAddImage(destination, image, options)
  guard CGImageDestinationFinalize(destination) else {
    fail("error: could not write \(path)")
  }
}

for name in ["Regular", "Medium", "Bold"] {
  let url = URL(
    fileURLWithPath:
      "/System/Applications/Utilities/Terminal.app/Contents/Resources/Fonts/SF-Mono-\(name).otf")
  CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

func systemFont(_ size: CGFloat, weight: CGFloat) -> CTFont {
  guard let base = CTFontCreateUIFontForLanguage(.system, size, nil) else {
    fail("error: no system font")
  }
  let traits = [kCTFontWeightTrait: weight] as CFDictionary
  let descriptor = CTFontDescriptorCreateCopyWithAttributes(
    CTFontCopyFontDescriptor(base), [kCTFontTraitsAttribute: traits] as CFDictionary)
  return CTFontCreateWithFontDescriptor(descriptor, size, nil)
}

func monoFont(_ size: CGFloat, medium: Bool = false) -> CTFont {
  CTFontCreateWithName((medium ? "SFMono-Medium" : "SFMono-Regular") as CFString, size, nil)
}

struct Board {
  let context: CGContext
  let width: CGFloat
  let height: CGFloat

  func line(_ text: String, _ font: CTFont, _ ink: CGColor, tracking: CGFloat = 0) -> CTLine {
    let attributes: [CFString: Any] = [
      kCTFontAttributeName: font, kCTForegroundColorAttributeName: ink, kCTKernAttributeName: tracking,
    ]
    return CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: attributes as [NSAttributedString.Key: Any]))
  }

  func width(_ text: String, _ font: CTFont, tracking: CGFloat = 0) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(line(text, font, color(0xFFFFFF), tracking: tracking), nil, nil, nil))
  }

  @discardableResult
  func text(
    _ text: String, _ font: CTFont, _ ink: CGColor, x: CGFloat, baseline: CGFloat,
    tracking: CGFloat = 0
  ) -> CGFloat {
    let ctLine = line(text, font, ink, tracking: tracking)
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: x, y: height - baseline)
    CTLineDraw(ctLine, context)
    return CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
  }

  func flipped(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
  }

  func fill(_ rect: CGRect, radius: CGFloat, _ ink: CGColor) {
    context.addPath(roundedRect(flipped(rect), radius))
    context.setFillColor(ink)
    context.fillPath()
  }

  func strokeRect(_ rect: CGRect, radius: CGFloat, width lineWidth: CGFloat, _ ink: CGColor) {
    context.addPath(roundedRect(flipped(rect).insetBy(dx: lineWidth / 2, dy: lineWidth / 2), radius))
    context.setLineWidth(lineWidth)
    context.setStrokeColor(ink)
    context.strokePath()
  }

  func image(_ image: CGImage, _ rect: CGRect) {
    context.interpolationQuality = .high
    context.draw(image, in: flipped(rect))
  }

  func backdrop(cornerRadius: CGFloat) {
    let full = CGRect(x: 0, y: 0, width: width, height: height)
    context.saveGState()
    if cornerRadius > 0 {
      context.addPath(roundedRect(full, cornerRadius))
      context.clip()
    }
    context.drawLinearGradient(
      gradient([
        (color(0x231733), 0), (color(0x4A2232), 0.28), (color(0x8C4132), 0.52),
        (color(0xBF7B3E), 0.76), (color(0xE8B24E), 1),
      ]), start: CGPoint(x: 0, y: 0), end: CGPoint(x: width, y: height * 1.25), options: [])
    let glow = CGPoint(x: width * 0.42, y: height * 1.0)
    context.drawRadialGradient(
      gradient([(color(0xB4523A, alpha: 0.35), 0), (color(0xB4523A, alpha: 0), 1)]),
      startCenter: glow, startRadius: 0, endCenter: glow, endRadius: width * 0.45, options: [])
    context.restoreGState()
  }

  func shadowed(blur: CGFloat, drop: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -drop), blur: blur, color: color(0x000000, alpha: alpha))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    draw()
    context.endTransparencyLayer()
    context.restoreGState()
  }
}

let panelBody = color(0x1E1E1E)
let panelHeader = color(0x232323)
let codeWell = color(0x262626)
let codeWellEdge = color(0x333333)
let textStrong = color(0xF2F2F2)
let textMuted = color(0x8E8E8E)
let textCode = color(0xE6E3DF)
let textVerb = color(0x8E8E8E)
let amberInk = color(0xE6B04A)

struct LogLine {
  let verb: String
  let path: String
}

let installCommand = "~/countersign-skills/install.sh"
let firstLinks = [
  LogLine(verb: "linked", path: "~/.claude/skills/orchestrate"),
  LogLine(verb: "linked", path: "~/.claude/skills/context-transfer"),
  LogLine(verb: "linked", path: "~/.agents/skills/context-transfer"),
  LogLine(verb: "linked", path: "~/.gemini/antigravity-cli/skills/context-transfer"),
]
let hiddenLinks = "41 more links"
let lastWrites = [
  LogLine(verb: "wrote", path: "~/.claude/CLAUDE.md"),
  LogLine(verb: "wrote", path: "~/.claude/settings.json"),
  LogLine(verb: "wrote", path: "~/.codex/AGENTS.md"),
  LogLine(verb: "wrote", path: "~/.gemini/GEMINI.md"),
]

func drawLog(_ board: Board, x: CGFloat, top: CGFloat, size: CGFloat, step: CGFloat) {
  let mono = monoFont(size)
  let verbColumn = board.width("linked  ", mono)
  var baseline = top
  let prompt = board.text("$ ", monoFont(size, medium: true), amberInk, x: x, baseline: baseline)
  board.text(installCommand, mono, textStrong, x: x + prompt, baseline: baseline)
  baseline += step
  for entry in firstLinks {
    board.text(entry.verb, mono, textVerb, x: x, baseline: baseline)
    board.text(entry.path, mono, textCode, x: x + verbColumn, baseline: baseline)
    baseline += step
  }
  board.text("⋯ \(hiddenLinks)", mono, textMuted, x: x + verbColumn, baseline: baseline)
  baseline += step
  for entry in lastWrites {
    board.text(entry.verb, mono, textVerb, x: x, baseline: baseline)
    board.text(entry.path, mono, textCode, x: x + verbColumn, baseline: baseline)
    baseline += step
  }
}

func drawPanelHeader(_ board: Board, panel: CGRect, height: CGFloat, scale: CGFloat) {
  let iconSide = 30 * scale
  let iconImage = renderIcon(pixels: Int(iconSide * 1024 / 824 * 2))
  let inset = iconSide * 100 / 824
  let iconX = panel.minX + 26 * scale
  let iconY = panel.minY + (height - iconSide) / 2
  board.image(
    iconImage,
    CGRect(x: iconX - inset, y: iconY - inset, width: iconSide + 2 * inset, height: iconSide + 2 * inset))
  let baseline = panel.minY + height / 2 + 6 * scale
  var x = iconX + iconSide + 14 * scale
  x += board.text("Terminal", systemFont(17 * scale, weight: 0.3), textStrong, x: x, baseline: baseline)
  x += 12 * scale
  x += board.text("›", systemFont(19 * scale, weight: 0.2), textMuted, x: x, baseline: baseline)
  x += 12 * scale
  board.text("countersign-skills", systemFont(17 * scale, weight: 0), textMuted, x: x, baseline: baseline)
  let chipFont = systemFont(14 * scale, weight: 0.3)
  let chipText = "POSIX sh"
  let chipWidth = board.width(chipText, chipFont) + 24 * scale
  let chipHeight = 28 * scale
  let chipRect = CGRect(
    x: panel.maxX - 22 * scale - chipWidth, y: panel.minY + (height - chipHeight) / 2,
    width: chipWidth, height: chipHeight)
  board.fill(chipRect, radius: chipHeight / 2, color(0xE6B04A, alpha: 0.16))
  board.text(
    chipText, chipFont, amberInk, x: chipRect.minX + 12 * scale,
    baseline: chipRect.minY + chipHeight / 2 + 5 * scale)
}

func drawPanel(_ board: Board, panel: CGRect, scale: CGFloat, footer: Bool) {
  let radius = 20 * scale
  let headerHeight = 52 * scale
  board.shadowed(blur: 40 * scale, drop: 14 * scale, alpha: 0.45) {
    board.fill(panel, radius: radius, panelBody)
  }
  board.context.saveGState()
  board.context.addPath(roundedRect(board.flipped(panel), radius))
  board.context.clip()
  board.fill(CGRect(x: panel.minX, y: panel.minY, width: panel.width, height: headerHeight), radius: 0, panelHeader)
  if footer {
    let footerHeight = 60 * scale
    board.fill(
      CGRect(x: panel.minX, y: panel.maxY - footerHeight, width: panel.width, height: footerHeight),
      radius: 0, panelHeader)
    let baseline = panel.maxY - footerHeight / 2 + 6 * scale
    var x = panel.minX + 26 * scale
    x += board.text("Linked into", systemFont(15 * scale, weight: 0), textMuted, x: x, baseline: baseline)
    x += 12 * scale
    let chipFont = systemFont(14 * scale, weight: 0.2)
    for agent in ["Claude Code", "Codex", "Antigravity"] {
      let chipWidth = board.width(agent, chipFont) + 20 * scale
      let chipHeight = 26 * scale
      let rect = CGRect(x: x, y: panel.maxY - footerHeight / 2 - chipHeight / 2, width: chipWidth, height: chipHeight)
      board.strokeRect(rect, radius: 7 * scale, width: 1.2 * scale, color(0xFFFFFF, alpha: 0.22))
      board.text(agent, chipFont, color(0xC8C8C8), x: x + 10 * scale, baseline: rect.minY + chipHeight / 2 + 5 * scale)
      x += chipWidth + 8 * scale
    }
    let note = "uninstall.sh puts it all back"
    let noteFont = systemFont(15 * scale, weight: 0)
    board.text(note, noteFont, textMuted, x: panel.maxX - 26 * scale - board.width(note, noteFont), baseline: baseline)
  }
  board.context.restoreGState()
  board.strokeRect(panel, radius: radius, width: 1 * scale, color(0xFFFFFF, alpha: 0.09))
  drawPanelHeader(board, panel: panel, height: headerHeight, scale: scale)
}

func renderHero(_ path: String) {
  let width = 1792
  let height = 1286
  let context = makeContext(width: width, height: height)
  let board = Board(context: context, width: CGFloat(width), height: CGFloat(height))
  board.backdrop(cornerRadius: 40)
  let scale: CGFloat = 2
  let panel = CGRect(x: 256, y: 200, width: 1280, height: 886)
  drawPanel(board, panel: panel, scale: scale, footer: true)
  board.text(
    "Install every skill, rule and agent", systemFont(34, weight: 0.4), textStrong,
    x: panel.minX + 40, baseline: panel.minY + 104 + 70)
  board.text(
    "One script for Claude Code, Codex and Antigravity", systemFont(26, weight: 0), textMuted,
    x: panel.minX + 40, baseline: panel.minY + 104 + 116)
  let well = CGRect(x: panel.minX + 40, y: panel.minY + 260, width: panel.width - 80, height: 476)
  board.fill(well, radius: 22, codeWell)
  board.strokeRect(well, radius: 22, width: 2, codeWellEdge)
  drawLog(board, x: well.minX + 36, top: well.minY + 58, size: 25, step: 40)
  guard let image = context.makeImage() else { fail("error: could not render the hero") }
  write(image, to: path)
}

func renderSocial(_ path: String) {
  let width = 1280
  let height = 640
  let context = makeContext(width: width, height: height)
  let board = Board(context: context, width: CGFloat(width), height: CGFloat(height))
  board.backdrop(cornerRadius: 0)
  let iconSide: CGFloat = 106
  let inset = iconSide * 100 / 824
  board.image(
    renderIcon(pixels: 512),
    CGRect(x: 86 - inset, y: 139 - inset, width: iconSide + 2 * inset, height: iconSide + 2 * inset))
  var titleSize: CGFloat = 82
  let title = "countersign-skills"
  while board.width(title, systemFont(titleSize, weight: 0.4), tracking: -1) > 500 { titleSize -= 1 }
  board.text(title, systemFont(titleSize, weight: 0.4), color(0xFFFFFF), x: 84, baseline: 330, tracking: -1)
  let tagFont = systemFont(30, weight: 0.3)
  let tagLines = ["Skills, rules and subagents for", "Claude Code, Codex and", "Antigravity, with one installer."]
  for (index, text) in tagLines.enumerated() {
    board.text(text, tagFont, color(0xFFFFFF, alpha: 0.92), x: 86, baseline: 410 + CGFloat(index) * 38)
  }
  let panel = CGRect(x: 616, y: 168, width: 600, height: 304)
  drawPanel(board, panel: panel, scale: 1, footer: false)
  let well = CGRect(x: panel.minX + 18, y: panel.minY + 68, width: panel.width - 36, height: panel.height - 86)
  board.fill(well, radius: 10, codeWell)
  board.strokeRect(well, radius: 10, width: 1, codeWellEdge)
  drawLog(board, x: well.minX + 16, top: well.minY + 26, size: 13, step: 20)
  guard let image = context.makeImage() else { fail("error: could not render the social preview") }
  write(image, to: path, type: "public.jpeg")
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "icon" where arguments.count == 3:
  guard let pixels = Int(arguments[1]) else { fail("usage: render icon <pixels> <out.png>") }
  write(renderIcon(pixels: pixels), to: arguments[2])
case "hero" where arguments.count == 2:
  renderHero(arguments[1])
case "social" where arguments.count == 2:
  renderSocial(arguments[1])
default:
  fail("usage: render icon <pixels> <out.png> | hero <out.png> | social <out.jpg>")
}
