// Scala scale file (.scl) reader and HTML renderer.
// Format (https://www.huygens-fokker.org/scala/scl_format.html):
//   ! comment lines, anywhere
//   description line (the first non-comment line, may be empty)
//   number of notes
//   one pitch per line: cents if the value contains a ".", otherwise a ratio "n/d" or an integer "n".
//   Anything after the value on a pitch line is ignored.
//   Degree 0 (1/1) is implicit; the last pitch is the period (usually 2/1).
import Foundation

public enum Scl {
    /// Renders an .scl file as a self-contained HTML page. Quick Look runs no JavaScript in previews,
    /// so the wheel and the keyboard are static SVG built here.
    public static func html(from data: Data, fileName: String? = nil) -> String {
        guard data.count <= 4_000_000 else {
            var s = Scale()
            s.error = tr("err.tooLarge", data.count / 1_000_000)
            return render(s, fileName: fileName)
        }
        return render(parse(decode(data)), fileName: fileName)
    }
}

// MARK: - Model

struct Pitch {
    let line: Int        // 0-based index into Scale.lines
    let token: String    // value as written
    let cents: Double
    let isRatio: Bool
}

enum Role { case comment, description, count, pitch, blank, extra, error }

struct Scale {
    var lines: [String] = []
    var roles: [Role] = []   // one per line, drives the source highlighting
    var description = ""
    var count: Int?
    var pitches: [Pitch] = []
    var error: String?
}

struct Degree {
    let index: Int
    let token: String
    let cents: Double
    let isRatio: Bool
    let label: String    // cents as shown: as written for cents values, computed (3 decimals) for ratios
    let black: Bool      // nearest 12-TET pitch class is a black piano key
    let nearest: String  // e.g. "G −2"
    let pos: Double      // position inside one period, 0 ..< period (the period degree itself sits at period)
}

// MARK: - Parsing

func decode(_ data: Data) -> String {
    var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
    return text
}

func parse(_ text: String) -> Scale {
    var s = Scale()
    var norm = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    if norm.hasSuffix("\n") { norm.removeLast() }
    s.lines = norm.isEmpty ? [] : norm.components(separatedBy: "\n")

    enum Stage { case description, count, pitches, done }
    var stage = Stage.description
    for (i, line) in s.lines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("!") { s.roles.append(.comment); continue }
        switch stage {
        case .description:
            s.description = trimmed
            s.roles.append(.description)
            stage = .count
        case .count:
            if trimmed.isEmpty { s.roles.append(.blank); continue }
            if let n = Int(firstToken(trimmed)), n >= 0 {
                s.count = n
                s.roles.append(.count)
                stage = n == 0 ? .done : .pitches
            } else {
                s.roles.append(.error)
                s.error = tr("err.expectCount", i + 1, trimmed)
                stage = .done
            }
        case .pitches:
            if trimmed.isEmpty { s.roles.append(.blank); continue }
            let tok = firstToken(trimmed)
            if let v = pitchValue(tok) {
                s.pitches.append(Pitch(line: i, token: tok, cents: v.cents, isRatio: v.isRatio))
                s.roles.append(.pitch)
                if s.pitches.count == s.count { stage = .done }
            } else {
                s.roles.append(.error)
                s.error = tr("err.badPitch", i + 1, tok)
                stage = .done
            }
        case .done:
            s.roles.append(trimmed.isEmpty ? .blank : .extra)
        }
    }
    if s.error == nil {
        switch stage {
        case .description: s.error = tr("err.empty")
        case .count: s.error = tr("err.noCount")
        case .pitches: s.error = tr("err.short", s.count ?? 0, s.pitches.count)
        case .done: break
        }
    }
    return s
}

func firstToken(_ s: String) -> String {
    s.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
}

/// Cents if the token contains a ".", otherwise a positive ratio "n/d" or integer "n".
func pitchValue(_ tok: String) -> (cents: Double, isRatio: Bool)? {
    if tok.contains(".") {
        guard tok.allSatisfy({ "0123456789.+-".contains($0) }), let c = Double(tok), c.isFinite else { return nil }
        return (c, false)
    }
    let parts = tok.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 1 || parts.count == 2,
          parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { ("0"..."9").contains($0) } }),
          let n = Double(parts[0]), let d = parts.count == 2 ? Double(parts[1]) : 1,
          n > 0, d > 0
    else { return nil }
    let c = 1200 * log2(n / d)
    return c.isFinite ? (c, true) : nil
}

// MARK: - Derived values

let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
let blackClasses: Set<Int> = [1, 3, 6, 8, 10]

func mod(_ a: Double, _ m: Double) -> Double {
    let r = fmod(a, m)
    return r < 0 ? r + m : r
}

/// Degrees 0 (the implicit 1/1) through N (the period).
func degrees(_ s: Scale, period: Double) -> [Degree] {
    let raw = [(token: "1/1", cents: 0.0, isRatio: true)]
        + s.pitches.map { (token: $0.token, cents: $0.cents, isRatio: $0.isRatio) }
    let last = raw.count - 1
    return raw.enumerated().map { (i, p) -> Degree in
        let step12 = (p.cents / 100).rounded()
        let pc = Int(mod(step12, 12)) % 12
        let dev = p.cents - step12 * 100
        var pos = mod(p.cents, period)
        if pos >= period - 1e-9 { pos = 0 }
        if i == last && i > 0 { pos = period }
        return Degree(
            index: i, token: p.token, cents: p.cents, isRatio: p.isRatio,
            label: p.isRatio ? fmt(p.cents) : cleanCents(p.token),
            black: blackClasses.contains(pc),
            nearest: noteNames[pc] + (abs(dev) < 0.05 ? "" : " " + signed(dev, 1)),
            pos: pos)
    }
}

/// Up to `digits` decimals, trailing zeros dropped, typographic minus.
func fmt(_ x: Double, _ digits: Int = 3) -> String {
    var s = String(format: "%.\(digits)f", x)
    if s.contains(".") {
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
    }
    if s == "-0" { s = "0" }
    return s.replacingOccurrences(of: "-", with: "−")
}

func signed(_ x: Double, _ digits: Int) -> String {
    let s = fmt(x, digits)
    return x > 0 && s != "0" ? "+" + s : s
}

func cleanCents(_ tok: String) -> String {
    var t = tok
    if t.hasPrefix("+") { t.removeFirst() }
    if t.hasPrefix(".") { t = "0" + t }
    if t.contains(".") {   // drop trailing zeros only; every written digit that matters stays
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
    }
    if t == "-0" || t.isEmpty { t = "0" }
    return t.replacingOccurrences(of: "-", with: "−")
}

// MARK: - HTML

func render(_ s: Scale, fileName: String?) -> String {
    let n = s.pitches.count
    let periodPitch = s.pitches.last
    let period = (periodPitch?.cents ?? 0) > 1e-6 ? periodPitch!.cents : 1200
    let degs = degrees(s, period: period)
    let ring = Array(degs.prefix(max(n, 1)))           // one period: degrees 0 ..< N
    let periodLabel = n > 0 ? degs[n].label : nil
    let title = fileName ?? (s.description.isEmpty ? tr("scale.untitled") : s.description)

    // Summary chips
    var chips: [String] = [trN("notes", n)]
    if let p = periodPitch {
        chips.append(tr("period", degs[n].label) + (p.isRatio ? " (\(p.token))" : ""))
    }
    let steps = zip(degs.dropFirst(), degs).map { $0.cents - $1.cents }
    if let lo = steps.min(), let hi = steps.max() {
        if lo > 0, hi - lo < 0.001 {
            chips.append(abs(period - 1200) < 0.001
                ? tr("equalOctave", n)
                : tr("equalPeriod", n))
            chips.append(tr("step", fmt(lo)))
        } else {
            chips.append(tr("steps", fmt(lo), fmt(hi)))
        }
        if lo <= 0 { chips.append(tr("notAscending")) }
    }
    if let c = s.count, c != n, s.error == nil { chips.append(tr("declared", c)) }

    let chipHTML = chips.map { "<span class=\"chip\">\(esc($0))</span>" }.joined()
    let errorHTML = s.error.map { "<div class=\"warn\">⚠︎ \(esc($0))</div>" } ?? ""
    let desc = s.description.isEmpty ? "<div class=\"desc mut\">\(esc(tr("noDescription")))</div>"
        : "<div class=\"desc\">\(esc(s.description))</div>"

    let centerLines = [periodLabel.map { tr("period", $0) }].compactMap { $0 }
    let body = s.lines.isEmpty && s.error != nil ? "" : """
        <div class="wheel">\(wheelSVG(ring, period: period, topLabel: periodLabel, count: n, extra: centerLines))</div>
        <h2>\(esc(tr("onePeriod")))</h2>
        <div class="piano">\(pianoSVG(degs, period: period))</div>
        <h2>\(esc(tr("degrees")))</h2>
        \(table(degs))
        """

    return """
    <!doctype html><html lang="\(uiLanguage)"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(esc(title))</title><style>\(css)</style></head><body>
    <main class="left">
    <h1>\(esc(title))</h1>\(desc)
    <div class="chips">\(chipHTML)</div>\(errorHTML)
    \(body)
    </main>
    <section class="right">
    <div class="srchead"><span>\(esc(tr("source")))</span><span class="mut">\(esc(trN("lines", s.lines.count)))</span></div>
    \(source(s))
    </section>
    </body></html>
    """
}

// MARK: Wheel

private func f(_ v: Double) -> String { String(format: "%.2f", v) }

func wheelSVG(_ ring: [Degree], period P: Double, topLabel: String?, count: Int, extra: [String]) -> String {
    let c = 240.0
    let sorted = ring.sorted { $0.pos != $1.pos ? $0.pos < $1.pos : $0.index < $1.index }
    let text = sorted.map { $0.index == 0 ? (topLabel ?? "0") : $0.label }
    func pt(_ cents: Double, _ rad: Double) -> (x: Double, y: Double) {
        let a = cents / P * 2 * Double.pi
        return (c + rad * sin(a), c - rad * cos(a))
    }
    func pillWidth(_ s: String) -> Double { Double(s.count) * 6.6 + 14 }

    // Pills on the ring (like a clock face) when they don't collide; otherwise dots + radial labels.
    let pillR = 172.0
    var pills = sorted.count <= 24
    if pills && sorted.count > 1 {
        for k in sorted.indices {
            let j = (k + 1) % sorted.count
            let a = pt(sorted[k].pos, pillR), b = pt(sorted[j].pos, pillR)
            if abs(a.x - b.x) < (pillWidth(text[k]) + pillWidth(text[j])) / 2 + 3 && abs(a.y - b.y) < 23 {
                pills = false
                break
            }
        }
    }
    let R = pills ? pillR : 150.0, r = R * 0.6

    // Crop the canvas to what the labels actually need.
    var ext = R + 14
    if pills {
        for (k, d) in sorted.enumerated() {
            let p = pt(d.pos, R)
            ext = max(ext, abs(p.x - c) + pillWidth(text[k]) / 2 + 2, abs(p.y - c) + 13)
        }
    } else {
        let longest = (sorted.count <= 96 ? text : [text[0]]).map(\.count).max() ?? 1
        ext = R + 11 + Double(longest) * 6.2 + 4
    }
    var out = "<svg viewBox=\"\(f(c - ext)) \(f(c - ext)) \(f(2 * ext)) \(f(2 * ext))\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\">"
    // Wedges: each degree owns the arc halfway to its neighbours. Scales with fewer than 12 notes would give a few
    // huge wedges, so they get 12 equal fields in the piano's white/black pattern instead (see gridPianoSVG); the
    // degrees still sit at their true positions (spokes and labels), and each field's tooltip lists the degrees in it.
    if count < 12 {
        for k in 0..<12 {
            let a0 = (Double(k) - 0.5) * P / 12, a1 = (Double(k) + 0.5) * P / 12
            let p0 = pt(a0, R), p1 = pt(a1, R), p2 = pt(a1, r), p3 = pt(a0, r)
            let here = sorted.filter { Int(($0.pos / P * 12).rounded()) % 12 == k }
            out += "<path class=\"\(blackClasses.contains(k) ? "kb" : "kw")\" d=\"M\(f(p0.x)),\(f(p0.y))A\(f(R)),\(f(R)) 0 0 1 \(f(p1.x)),\(f(p1.y))"
                + "L\(f(p2.x)),\(f(p2.y))A\(f(r)),\(f(r)) 0 0 0 \(f(p3.x)),\(f(p3.y))Z\">"
                + here.map { "<title>\(esc(tip($0)))</title>" }.joined() + "</path>"
        }
    } else if sorted.count == 1 {
        out += "<circle cx=\"\(f(c))\" cy=\"\(f(c))\" r=\"\(f((R + r) / 2))\" fill=\"none\" class=\"\(sorted[0].black ? "kbs" : "kws")\" stroke-width=\"\(f(R - r))\"/>"
    } else {
        for (k, d) in sorted.enumerated() {
            let prev = k == 0 ? sorted[sorted.count - 1].pos - P : sorted[k - 1].pos
            let next = k == sorted.count - 1 ? sorted[0].pos + P : sorted[k + 1].pos
            let a0 = (prev + d.pos) / 2, a1 = (d.pos + next) / 2
            guard a1 - a0 > 1e-9 else { continue }
            let large = a1 - a0 > P / 2 ? 1 : 0
            let p0 = pt(a0, R), p1 = pt(a1, R), p2 = pt(a1, r), p3 = pt(a0, r)
            out += "<path class=\"\(d.black ? "kb" : "kw")\" d=\"M\(f(p0.x)),\(f(p0.y))A\(f(R)),\(f(R)) 0 \(large) 1 \(f(p1.x)),\(f(p1.y))"
                + "L\(f(p2.x)),\(f(p2.y))A\(f(r)),\(f(r)) 0 \(large) 0 \(f(p3.x)),\(f(p3.y))Z\">"
                + "<title>\(esc(tip(d)))</title></path>"
        }
    }
    for d in sorted {
        let a = pt(d.pos, r), b = pt(d.pos, R)
        out += "<line class=\"as spoke\" x1=\"\(f(a.x))\" y1=\"\(f(a.y))\" x2=\"\(f(b.x))\" y2=\"\(f(b.y))\"/>"
    }
    out += "<circle class=\"hole\" cx=\"\(f(c))\" cy=\"\(f(c))\" r=\"\(f(r))\"/>"
    out += "<circle class=\"as ring\" cx=\"\(f(c))\" cy=\"\(f(c))\" r=\"\(f(R))\"/>"

    // Labels
    for (k, d) in sorted.enumerated() {
        let p = pt(d.pos, R)
        let top = d.index == 0
        if pills {
            let w = pillWidth(text[k])
            out += "<g class=\"pill\(top ? " top" : "")\"><rect class=\"\(top ? "" : "af")\" x=\"\(f(p.x - w / 2))\" y=\"\(f(p.y - 11))\" width=\"\(f(w))\" height=\"22\" rx=\"11\"/>"
                + "<text x=\"\(f(p.x))\" y=\"\(f(p.y))\" text-anchor=\"middle\" dominant-baseline=\"central\">\(esc(text[k]))</text></g>"
        } else {
            out += "<circle class=\"\(top ? "dot0" : "af")\" cx=\"\(f(p.x))\" cy=\"\(f(p.y))\" r=\"\(top ? 5 : 3.5)\"/>"
            guard sorted.count <= 96 || top else { continue }
            let deg = d.pos / P * 360
            let left = deg > 180.0001
            let rho = R + 11
            out += "<text class=\"rl\(top ? " b" : "")\" transform=\"rotate(\(f(left ? deg + 90 : deg - 90)) \(f(c)) \(f(c)))\" "
                + "x=\"\(f(left ? c - rho : c + rho))\" y=\"\(f(c))\" text-anchor=\"\(left ? "end" : "start")\" "
                + "dominant-baseline=\"central\">\(esc(text[k]))</text>"
        }
    }
    // Centre
    out += "<text class=\"cbig\" x=\"\(f(c))\" y=\"\(f(c - 10))\" text-anchor=\"middle\">\(count)</text>"
    out += "<text class=\"csmall\" x=\"\(f(c))\" y=\"\(f(c + 14))\" text-anchor=\"middle\">\(esc(trN("noteWord", count)))</text>"
    for (i, line) in extra.enumerated() {
        out += "<text class=\"csmall\" x=\"\(f(c))\" y=\"\(f(c + 34 + Double(i) * 18))\" text-anchor=\"middle\">\(esc(line))</text>"
    }
    return out + "</svg>"
}

func tip(_ d: Degree) -> String {
    tr("tip", d.index, d.token, d.label, d.nearest)
}

// MARK: Keyboard

/// One period as a keyboard: key widths follow pitch spacing. Every degree owns the span halfway to its
/// neighbours; white keys additionally share the lower half among themselves, like a piano.
func pianoSVG(_ degs: [Degree], period P: Double) -> String {
    if degs.count - 1 < 12 { return gridPianoSVG(degs, period: P) }   // few degrees: a full 12-field keyboard
    let W = 1000.0, H = 150.0, HB = 94.0
    let keys = degs.sorted { $0.pos != $1.pos ? $0.pos < $1.pos : $0.index < $1.index }
    var left = -P / 2, right = P / 2
    if keys.count > 1 {
        left = keys[0].pos - (keys[1].pos - keys[0].pos) / 2
        right = keys[keys.count - 1].pos + (keys[keys.count - 1].pos - keys[keys.count - 2].pos) / 2
    }
    if right - left < 1e-9 { left = -1; right = P + 1 }
    func X(_ c: Double) -> Double { (c - left) / (right - left) * W }
    func slots(_ ks: [Degree]) -> [(lo: Double, hi: Double)] {
        ks.indices.map { k in
            (lo: k == 0 ? left : (ks[k - 1].pos + ks[k].pos) / 2,
             hi: k == ks.count - 1 ? right : (ks[k].pos + ks[k + 1].pos) / 2)
        }
    }
    let whites = keys.filter { !$0.black }
    let lastIndex = degs.count - 1

    var out = "<svg viewBox=\"0 0 \(f(W)) \(f(H + 2))\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\">"
    for (d, s) in zip(whites, slots(whites)) {
        let x0 = X(s.lo), w = X(s.hi) - x0, cx = x0 + w / 2
        out += "<rect class=\"kw\" x=\"\(f(x0 + 0.75))\" y=\"1\" width=\"\(f(max(w - 1.5, 0.5)))\" height=\"\(f(H))\" rx=\"5\"><title>\(esc(tip(d)))</title></rect>"
        if d.index == 0 || (d.index == lastIndex && lastIndex > 0) {
            out += "<circle class=\"af\" cx=\"\(f(cx))\" cy=\"\(f(H - 34))\" r=\"5\"/>"
        }
        if w >= 22 { out += "<text class=\"kl\" x=\"\(f(cx))\" y=\"\(f(H - 12))\" text-anchor=\"middle\">\(d.index)</text>" }
    }
    for (d, s) in zip(keys, slots(keys)) where d.black {
        let x0 = X(s.lo), w = X(s.hi) - x0, inset = min(3, w * 0.12), cx = x0 + w / 2
        out += "<rect class=\"kb\" x=\"\(f(x0 + inset))\" y=\"1\" width=\"\(f(max(w - 2 * inset, 0.5)))\" height=\"\(f(HB))\" rx=\"4\"><title>\(esc(tip(d)))</title></rect>"
        if d.index == 0 || (d.index == lastIndex && lastIndex > 0) {
            out += "<circle class=\"af\" cx=\"\(f(cx))\" cy=\"\(f(HB - 30))\" r=\"5\"/>"
        }
        if w >= 22 { out += "<text class=\"kbl\" x=\"\(f(cx))\" y=\"\(f(HB - 10))\" text-anchor=\"middle\">\(d.index)</text>" }
    }
    return out + "</svg>"
}

/// Scales with fewer than 12 notes would give a handful of huge keys, so they get a regular 12-field keyboard
/// instead (7 white and 5 black fields, like one octave of a piano). The period is cut into 12 equal fields, which for an
/// octave scale is exactly 12-TET, and each degree marks the field it falls in, with its number and an accent dot.
func gridPianoSVG(_ degs: [Degree], period P: Double) -> String {
    let W = 1000.0, H = 150.0, HB = 94.0
    let whitePCs = [0, 2, 4, 5, 7, 9, 11]
    let w = W / Double(whitePCs.count)
    let one = degs.count > 1 ? Array(degs.dropLast()) : degs      // degrees 0 ..< N (the period repeats degree 0)
    var onKey = [Int: [Degree]]()
    for d in one {
        let field = Int((mod(d.cents, P) / P * 12).rounded()) % 12
        onKey[field, default: []].append(d)
    }
    func marks(_ field: Int, dotY: Double, labelY: Double, cx: Double, labelClass: String) -> String {
        guard let ds = onKey[field] else { return "" }
        return "<circle class=\"af\" cx=\"\(f(cx))\" cy=\"\(f(dotY))\" r=\"5\"/>"
            + "<text class=\"\(labelClass)\" x=\"\(f(cx))\" y=\"\(f(labelY))\" text-anchor=\"middle\">\(ds.map { String($0.index) }.joined(separator: ","))</text>"
    }
    func titles(_ field: Int) -> String {
        (onKey[field] ?? []).map { "<title>\(esc(tip($0)))</title>" }.joined()
    }

    var out = "<svg viewBox=\"0 0 \(f(W)) \(f(H + 2))\" xmlns=\"http://www.w3.org/2000/svg\" role=\"img\">"
    for (i, pc) in whitePCs.enumerated() {
        let x0 = Double(i) * w
        out += "<rect class=\"kw\" x=\"\(f(x0 + 0.75))\" y=\"1\" width=\"\(f(w - 1.5))\" height=\"\(f(H))\" rx=\"5\">\(titles(pc))</rect>"
        out += marks(pc, dotY: H - 34, labelY: H - 12, cx: x0 + w / 2, labelClass: "kl")
    }
    let bw = w * 0.6
    for pc in blackClasses.sorted() {
        let boundary = Double(whitePCs.firstIndex(of: pc - 1)! + 1) * w     // black key sits between its white neighbours
        let x0 = boundary - bw / 2
        out += "<rect class=\"kb\" x=\"\(f(x0))\" y=\"1\" width=\"\(f(bw))\" height=\"\(f(HB))\" rx=\"4\">\(titles(pc))</rect>"
        out += marks(pc, dotY: HB - 30, labelY: HB - 10, cx: boundary, labelClass: "kbl")
    }
    return out + "</svg>"
}

// MARK: Table and source

func table(_ degs: [Degree]) -> String {
    var rows = ""
    for (i, d) in degs.enumerated() {
        let step = i == 0 ? "" : fmt(d.cents - degs[i - 1].cents)
        rows += "<tr><td class=\"idx\"><span class=\"sw\(d.black ? " b" : "")\"></span>\(d.index)</td>"
            + "<td class=\"val\">\(esc(d.token))</td><td class=\"num\">\(esc(d.label))</td>"
            + "<td class=\"num mut\">\(esc(step))</td><td>\(esc(d.nearest))</td></tr>"
    }
    return """
    <table><thead><tr><th class="idx">#</th><th>\(esc(tr("col.value")))</th><th class="num">\(esc(tr("col.cents")))</th>\
    <th class="num">\(esc(tr("col.step")))</th><th>\(esc(tr("col.nearest")))</th></tr></thead><tbody>\(rows)</tbody></table>
    """
}

func source(_ s: Scale) -> String {
    let width = max(2, String(s.lines.count).count)
    var out = "<div class=\"code\" style=\"--nw:\(width + 1)ch\">"
    for (i, line) in s.lines.enumerated() {
        let role = i < s.roles.count ? s.roles[i] : .extra
        var html: String
        switch role {
        case .comment: html = "<span class=\"c\">\(esc(line))</span>"
        case .description: html = "<span class=\"d\">\(esc(line))</span>"
        case .extra: html = "<span class=\"x\">\(esc(line))</span>"
        case .error: html = "<span class=\"e\">\(esc(line))</span>"
        case .blank: html = esc(line)
        case .count, .pitch:
            let lead = line.prefix { $0 == " " || $0 == "\t" }
            let rest = line.dropFirst(lead.count)
            let tok = rest.prefix { $0 != " " && $0 != "\t" }
            let tail = rest.dropFirst(tok.count)
            html = esc(String(lead)) + "<span class=\"ac v\">\(esc(String(tok)))</span>"
                + "<span class=\"r\">\(esc(String(tail)))</span>"
        }
        out += "<div class=\"ln\"><span class=\"no\">\(i + 1)</span><span class=\"tx\">\(html.isEmpty ? " " : html)</span></div>"
    }
    return out + "</div>"
}

func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}

// Neutral greys and plain black/white keys; the only colour is the system accent.
let css = """
:root{color-scheme:light dark;--bg:#fff;--fg:#1d1d1f;--mut:#86868b;--line:#e3e3e6;--panel:#f6f6f7;\
--kw:#fff;--kb:#1d1d1f;--edge:#bdbdc2;--kbt:#a1a1a6}
@media(prefers-color-scheme:dark){:root{--bg:#1e1e1e;--fg:#f2f2f7;--mut:#98989d;--line:#363638;\
--panel:#171717;--kw:#ececee;--kb:#0c0c0d;--edge:#5c5c60;--kbt:#8e8e93}}
*{box-sizing:border-box}
html,body{margin:0;height:100%}
body{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(0,1fr);background:var(--bg);color:var(--fg);\
font:13px/1.4 -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif}
.af{fill:#007aff;fill:AccentColor;fill:-apple-system-control-accent}
.as{stroke:#007aff;stroke:AccentColor;stroke:-apple-system-control-accent}
.ac{color:#007aff;color:AccentColor;color:-apple-system-control-accent}
.mut{color:var(--mut)}
.left{overflow:auto;padding:22px 26px 28px}
h1{font-size:19px;margin:0;word-break:break-word}
.desc{margin-top:2px;font-size:13px}
h2{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--mut);margin:22px 0 8px}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin-top:12px}
.chip{border:1px solid var(--line);border-radius:999px;padding:2px 9px;font-size:12px;white-space:nowrap}
.warn{margin-top:12px;padding:8px 11px;border:1px solid var(--fg);border-radius:8px;font-weight:500}
.wheel{max-width:400px;margin:18px auto 0}
.wheel svg,.piano svg{display:block;width:100%;height:auto}
svg text{font-family:-apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif}
.kw{fill:var(--kw);stroke:var(--edge);stroke-width:1}
.kb{fill:var(--kb);stroke:var(--edge);stroke-width:1}
.kws{stroke:var(--kw)}.kbs{stroke:var(--kb)}
.spoke{stroke-width:1.2;opacity:.55}
.hole{fill:var(--bg);stroke:var(--edge);stroke-width:1}
.ring{fill:none;stroke-width:3}
.pill text{fill:#fff;font-size:11px;font-weight:600;font-variant-numeric:tabular-nums}
.pill.top rect{fill:var(--fg)}.pill.top text{fill:var(--bg)}
.dot0{fill:var(--fg)}
.rl{fill:var(--fg);font-size:10px;font-variant-numeric:tabular-nums}.rl.b{font-weight:700}
.cbig{fill:var(--fg);font-size:46px;font-weight:600}
.csmall{fill:var(--mut);font-size:13px}
.kl{fill:var(--mut);font-size:15px}.kbl{fill:var(--kbt);font-size:15px}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}
th{font-weight:600;color:var(--mut);font-size:11px;text-align:left;padding:4px 8px;border-bottom:1px solid var(--line)}
td{padding:3px 8px;border-bottom:1px solid var(--line)}
.num{text-align:right}.idx{width:4em;white-space:nowrap}.val{font-family:ui-monospace,Menlo,monospace;font-size:12px}
.sw{display:inline-block;width:9px;height:9px;border:1px solid var(--edge);background:var(--kw);border-radius:2px;margin-right:7px}
.sw.b{background:var(--kb)}
.right{overflow:auto;border-left:1px solid var(--line);background:var(--panel)}
.srchead{position:sticky;top:0;display:flex;justify-content:space-between;padding:10px 16px;background:var(--panel);\
border-bottom:1px solid var(--line);font-weight:600;font-size:12px}
.code{font:12px/1.6 ui-monospace,Menlo,monospace;padding:8px 0 16px;min-width:max-content}
.ln{display:flex;padding-right:16px}
.no{flex:none;width:calc(var(--nw) + 18px);padding-right:14px;text-align:right;color:var(--mut);opacity:.7;user-select:none;-webkit-user-select:none}
.tx{white-space:pre;tab-size:4}
.c{color:var(--mut);font-style:italic}.d{font-weight:700}.r{color:var(--mut)}.x{color:var(--mut);opacity:.6}
.e{text-decoration:underline wavy;font-weight:700}
@media(max-width:760px){html,body{height:auto}body{display:block}.left,.right{overflow:visible}\
.right{border-left:0;border-top:1px solid var(--line)}.srchead{position:static}}
"""
