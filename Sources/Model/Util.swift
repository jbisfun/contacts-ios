import Foundation
import SwiftUI

extension String {
    /// Digits and a leading '+', like PhoneNumberUtils.normalizeNumber.
    var normalizedPhoneNumber: String {
        var out = ""
        for (i, ch) in self.enumerated() {
            if ch.isNumber, ch.isASCII { out.append(ch) } else if ch == "+" && i == 0 { out.append(ch) }
        }
        return out
    }

    /// Fossify's formatPhoneNumber(). Numbers already typed with separators are kept
    /// as written; bare NANP and +1 numbers get the familiar grouping.
    var formattedPhoneNumber: String {
        let n = normalizedPhoneNumber
        guard n == self, !n.isEmpty else { return self }
        let digits = n.hasPrefix("+") ? String(n.dropFirst()) : n
        func nanp(_ d: Substring) -> String {
            let a = d.prefix(3), b = d.dropFirst(3).prefix(3), c = d.dropFirst(6)
            return "(\(a)) \(b)-\(c)"
        }
        let region = Locale.current.region?.identifier ?? "US"
        if n.hasPrefix("+1"), digits.count == 11 { return "+1 " + nanp(digits.dropFirst()) }
        if !n.hasPrefix("+"), digits.count == 10, region == "US" || region == "CA" {
            return nanp(Substring(digits))
        }
        if !n.hasPrefix("+"), digits.count == 7 { return "\(digits.prefix(3))-\(digits.dropFirst(3))" }
        return self
    }

    /// java.lang.String.hashCode(), so letter avatars get the same color as on Android.
    var javaHashCode: Int32 {
        var h: Int32 = 0
        for u in utf16 { h = h &* 31 &+ Int32(u) }
        return h
    }

    /// String.getNameLetter(): first user visible grapheme, uppercased.
    var nameLetter: String {
        for ch in self where ch.isLetter || ch.isNumber || ch.unicodeScalars.contains(where: { $0.properties.isEmoji && $0.value > 0x238C }) {
            return String(ch).uppercased()
        }
        return "A"
    }

    /// Normalizes text for search: case/diacritic insensitive.
    var searchNormalized: String { folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) }
}

/// highlightTextPart(): colors every occurrence of `part` inside `text`.
func highlighted(_ text: String, _ part: String, color: Color) -> AttributedString {
    var a = AttributedString(text)
    guard !part.isEmpty else { return a }
    var searchRange = a.startIndex..<a.endIndex
    while let r = a[searchRange].range(of: part, options: [.caseInsensitive, .diacriticInsensitive]) {
        a[r].foregroundColor = color
        searchRange = r.upperBound..<a.endIndex
    }
    // Numbers: match digits ignoring formatting (e.g. "5551" in "(555) 123").
    if a.runs.count == 1, part.allSatisfy(\.isNumber) {
        let chars = Array(text)
        var map: [Int] = []
        var digits = ""
        for (i, c) in chars.enumerated() where c.isNumber { map.append(i); digits.append(c) }
        if let r = digits.range(of: part) {
            let s = digits.distance(from: digits.startIndex, to: r.lowerBound)
            let e = s + part.count - 1
            let start = a.index(a.startIndex, offsetByCharacters: map[s])
            let end = a.index(a.startIndex, offsetByCharacters: map[e] + 1)
            a[start..<end].foregroundColor = color
        }
    }
    return a
}

enum Launcher {
    static func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    static func call(_ number: String) {
        open(URL(string: "tel:" + number.normalizedPhoneNumber))
    }

    static func sms(_ numbers: [String]) {
        let list = numbers.map(\.normalizedPhoneNumber).filter { !$0.isEmpty }
        guard !list.isEmpty else { return }
        if list.count == 1 {
            open(URL(string: "sms:" + list[0]))
        } else {
            open(URL(string: "sms:/open?addresses=" + list.joined(separator: ",")))
        }
    }

    static func email(_ addresses: [String]) {
        let list = addresses.filter { !$0.isEmpty }
        guard !list.isEmpty,
              let s = ("mailto:" + list.joined(separator: ",")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }
        open(URL(string: s))
    }

    static func map(_ address: String) {
        var c = URLComponents(string: "maps://")!
        c.queryItems = [URLQueryItem(name: "q", value: address)]
        open(c.url)
    }

    static func website(_ value: String) {
        let v = value.contains("://") ? value : "https://" + value
        open(URL(string: v))
    }
}
