import JavaScriptCore
import Foundation

struct ViewNodeParser {
    static func parse(_ jsValue: JSValue) -> ViewNode {
        guard jsValue.isObject, let type = jsValue.forProperty("type")?.toString() else {
            return .empty
        }

        let style = parseStyle(jsValue.forProperty("style"))

        switch type {
        case "text":
            let content = jsValue.forProperty("content")?.toString() ?? ""
            return .text(content, style)

        case "image":
            let name = jsValue.forProperty("systemName")?.toString() ?? "questionmark"
            return .image(systemName: name, style)

        case "hstack":
            let children = parseChildren(jsValue.forProperty("children"))
            let spacing = jsValue.forProperty("spacing")?.isUndefined == false
                ? CGFloat(jsValue.forProperty("spacing")!.toDouble()) : nil
            return .hstack(children, spacing: spacing, style)

        case "vstack":
            let children = parseChildren(jsValue.forProperty("children"))
            let spacing = jsValue.forProperty("spacing")?.isUndefined == false
                ? CGFloat(jsValue.forProperty("spacing")!.toDouble()) : nil
            return .vstack(children, spacing: spacing, style)

        case "zstack":
            let children = parseChildren(jsValue.forProperty("children"))
            return .zstack(children, style)

        case "spacer":
            let minLength = jsValue.forProperty("minLength")?.isUndefined == false
                ? CGFloat(jsValue.forProperty("minLength")!.toDouble()) : nil
            return .spacer(minLength: minLength)

        case "divider":
            return .divider

        case "progress":
            let value = jsValue.forProperty("value")?.toDouble() ?? 0
            let total = jsValue.forProperty("total")?.toDouble() ?? 1
            return .progress(value: value, total: total, style)

        case "capsule":
            let child = jsValue.forProperty("child").map { parse($0) } ?? .empty
            return .capsule(child: child, style)

        default:
            return .empty
        }
    }

    private static func parseChildren(_ jsValue: JSValue?) -> [ViewNode] {
        guard let arr = jsValue, arr.isArray else { return [] }
        let length = arr.forProperty("length")?.toInt32() ?? 0
        return (0..<length).compactMap { i in
            guard let child = arr.atIndex(Int(i)) else { return nil }
            return parse(child)
        }
    }

    private static func parseStyle(_ jsValue: JSValue?) -> ViewNodeStyle {
        guard let s = jsValue, s.isObject else { return .empty }

        var style = ViewNodeStyle()
        if let v = s.forProperty("fontSize"), !v.isUndefined { style.fontSize = CGFloat(v.toDouble()) }
        if let v = s.forProperty("fontWeight"), !v.isUndefined { style.fontWeight = v.toString() }
        if let v = s.forProperty("fontDesign"), !v.isUndefined { style.fontDesign = v.toString() }
        if let v = s.forProperty("foregroundColor"), !v.isUndefined { style.foregroundColor = v.toString() }
        if let v = s.forProperty("backgroundColor"), !v.isUndefined { style.backgroundColor = v.toString() }
        if let v = s.forProperty("opacity"), !v.isUndefined { style.opacity = CGFloat(v.toDouble()) }
        if let v = s.forProperty("padding"), !v.isUndefined { style.padding = CGFloat(v.toDouble()) }
        if let v = s.forProperty("paddingEdges"), !v.isUndefined { style.paddingEdges = v.toString() }
        if let v = s.forProperty("cornerRadius"), !v.isUndefined { style.cornerRadius = CGFloat(v.toDouble()) }
        if let v = s.forProperty("lineLimit"), !v.isUndefined { style.lineLimit = Int(v.toInt32()) }

        if let f = s.forProperty("frame"), f.isObject {
            var frame = ViewNodeFrame()
            if let v = f.forProperty("width"), !v.isUndefined { frame.width = CGFloat(v.toDouble()) }
            if let v = f.forProperty("height"), !v.isUndefined { frame.height = CGFloat(v.toDouble()) }
            if let v = f.forProperty("maxWidth"), !v.isUndefined { frame.maxWidth = CGFloat(v.toDouble()) }
            if let v = f.forProperty("maxHeight"), !v.isUndefined { frame.maxHeight = CGFloat(v.toDouble()) }
            if let v = f.forProperty("alignment"), !v.isUndefined { frame.alignment = v.toString() }
            style.frame = frame
        }

        return style
    }
}
