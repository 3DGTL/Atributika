//
//  Detection.swift
//  Atributika
//
//  Created by Pavel Sharanda on 21.02.17.
//  Copyright © 2017 psharanda. All rights reserved.
//

import Foundation

public struct Tag {
    public let name: String
    public let attributes: [String: String]
    public let original: String?

    init(name: String, attributes: [String: String], original: String? = nil) {
        self.name = name
        self.attributes = attributes
        self.original = original
    }
}

public struct TagInfo {
    public let tag: Tag
    public let range: Range<Int>
}

extension String {

    private func parseTag(_ tagString: String, parseAttributes: Bool) -> Tag? {

        let tagScanner = Scanner(string: tagString)

        guard let tagName = tagScanner.scanCharacters(from: CharacterSet.alphanumerics) else {
            return nil
        }

        var attrubutes = [String: String]()

        while parseAttributes && !tagScanner.isAtEnd {

            guard let name = tagScanner.scanUpTo("=") else {
                break
            }

            guard tagScanner.scanString("=") != nil else {
                break
            }

            guard tagScanner.scanString("\"") != nil else {
                break
            }

            guard let value = tagScanner.scanUpTo("\"") else {
                break
            }

            guard tagScanner.scanString("\"") != nil else {
                break
            }

            attrubutes[name] = value.replacingOccurrences(of: "&quot;", with: "\"")
        }

        //reconstruct the original tag
        let original = "<\(tagString)\(parseAttributes ? "" : "/")>"
        return Tag(name: tagName, attributes: attrubutes, original: original)
    }

    private static let specials = ["quot": "\"",
                                   "amp": "&",
                                   "apos": "'",
                                   "lt": "<",
                                   "gt": ">"]

    public func detectTags(_ supportedTags: [String] = [String]()) -> (string: String, tagsInfo: [TagInfo]) {

        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil
        var resultString = String()
        var tagsResult = [TagInfo]()
        var tagsStack = [(Tag, Int)]()

        while !scanner.isAtEnd {

            if let textString = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "<&")) {
                resultString += textString
            } else {
                if scanner.scanString("<") != nil {
                    let open = scanner.scanString("/") == nil
                    if let tagString = scanner.scanUpTo(">") {

                        let parsedTag = parseTag(tagString, parseAttributes: open)
                        //check if tag is parsed and supported
                        if let tag = parsedTag, supportedTags.contains(tag.name) {

                            if tag.name == "br" {
                                resultString += "\n"
                            } else {
                                let resultTextEndIndex = resultString.characters.count

                                if open {
                                    tagsStack.append((tag, resultTextEndIndex))
                                } else {
                                    for (index, (tagInStack, startIndex)) in tagsStack.enumerated().reversed() {
                                        if tagInStack.name == tag.name {
                                            tagsResult.append(TagInfo(tag: tagInStack, range: startIndex..<resultTextEndIndex))
                                            tagsStack.remove(at: index)
                                            break
                                        }
                                    }
                                }
                            }
                        } else {
                            //add the unsupported tag to the output
                            resultString += parsedTag?.original ?? ""
                        }
                        scanner.scanString(">")
                    }
                } else if scanner.scanString("&") != nil {
                    if let specialString = scanner.scanUpTo(";") {
                        if let spec = String.specials[specialString] {
                            resultString += spec
                        }
                        scanner.scanString(";")
                    }
                }
            }
        }
        return (resultString, tagsResult)
    }

    public func detectHashTags() -> [Range<Int>] {

        return detect(regex: "[#]\\w\\S*\\b")
    }

    public func detectMentions() -> [Range<Int>] {

        return detect(regex: "[@]\\w\\S*\\b")
    }

    public func detect(regex: String, options: NSRegularExpression.Options = []) -> [Range<Int>] {

        var ranges = [Range<Int>]()

        let dataDetector = try? NSRegularExpression(pattern: regex, options: options)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = r.range.toRange() {
                ranges.append(range)
            }
        })

        return ranges
    }

    public func detect(textCheckingTypes: NSTextCheckingTypes) -> [Range<Int>] {

        var ranges = [Range<Int>]()

        let dataDetector = try? NSDataDetector(types: textCheckingTypes)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = r.range.toRange() {
                ranges.append(range)
            }
        })
        return ranges
    }
}
