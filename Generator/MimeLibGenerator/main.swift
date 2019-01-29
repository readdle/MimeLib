//
//  main.swift
//  MimeLibGenerator
//
//  Created by Ondrej Rafaj on 14/12/2016.
//  Copyright © 2016 manGoweb UK Ltd. All rights reserved.
//

import Foundation


// MARK: Start program

print("MimeLibGenerator starting ...\n")

// MARK: Getting arguments

var path: String = ""

var c = 0;
for arg in CommandLine.arguments {
    if c == 1 && arg.count > 0 {
        path = arg
        print("Export path set to: " + path)
    }
    c += 1
}

func removeSymbol(enumExt: inout String, separator: String) {
    if enumExt.contains(separator) {
        let arr = enumExt.components(separatedBy: separator)
        var x = 0
        for part in arr {
            if x == 0 {
                enumExt = part
            }
            else {
                enumExt += part.capitalizingFirstLetter()
            }
            x += 1
        }
    }
}

func mimeEnumCase(mime: String) -> String {
    if (mime == "~") {
        return "trash"
    }
    var enumExt = mime
    if Int(enumExt.substr(0)) != nil || enumExt == "class" {
        enumExt = "_" + enumExt
    }
    
    removeSymbol(enumExt: &enumExt, separator: "-")
    return enumExt
}

func getAndroidSourceCode(from: String) -> String {
    guard let url: URL = URL(string: from) else {
        fatalError("Wrong url \(from)")
    }
    guard let base64DataString: String = try? String(contentsOf: url) else {
        fatalError("Can't read source file from android.googlesource.com")
    }
    guard let data: Data = Data(base64Encoded: base64DataString) else {
        fatalError("It's not a base64")
    }
    guard let dataString = String(data: data, encoding: .utf8) else {
        fatalError("It's not a UTF8 string")
    }
    try! dataString.write(to: URL(fileURLWithPath: "/Users/admin/Desktop/mime.txt"), atomically: true, encoding: .utf8)
    return dataString
}

var mimeToExtension = [String: String]()
var extensionToMime = [String: String]()
var mimeOriginalOrder = [String]()
var extensionOriginalOrder = [String]()

func handle(ext extensions: [String], mime: String) {
    if mime.isEmpty {
        return
    }
    
    guard let firstExtension = extensions.first else {
        print("\(mime) without extensions")
        return
    }
    
    mimeToExtension[mime] = firstExtension
    if !mimeOriginalOrder.contains(mime) {
        mimeOriginalOrder.append(mime)
    }
    
    for ext in extensions {
        if ext.last == "!" {
            let forceExtension = String(ext.dropLast())
            // Special cases where Android has a strong opinion about mappings, so we
            // define them very last and use "!" to ensure that we force the mapping
            // in both directions.
            mimeToExtension[mime] = forceExtension
            extensionToMime[forceExtension] = mime
            if !mimeOriginalOrder.contains(mime) {
                mimeOriginalOrder.append(mime)
            }
            if !extensionOriginalOrder.contains(forceExtension) {
                extensionOriginalOrder.append(forceExtension)
            }
        }
        else {
            extensionToMime[ext] = mime
            if !extensionOriginalOrder.contains(ext) {
                extensionOriginalOrder.append(ext)
            }
        }
    }
}

func loadMime(dataString: String) {
    for line in dataString.lines {
        guard line.substr(0) != "#" else {
            continue
        }
        
        let parts = line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
        
        guard let mime = parts.first?.lowercased() else {
            continue
        }
        
        let extensions = parts.dropFirst().map { $0.lowercased() }
        handle(ext: extensions, mime: mime)
    }
}

// We load mime.types from 3 sources
// 1. mime.types from svn.apache.org
// 2. mime.types from android.googlesource.com (base64)
// 3. android.mime.types from android.googlesource.com (base64)
loadMime(dataString: try! String(contentsOf: URL(string: "http://svn.apache.org/repos/asf/httpd/httpd/trunk/docs/conf/mime.types")!))
loadMime(dataString: getAndroidSourceCode(from: "https://android.googlesource.com/platform/libcore/+/master/luni/src/main/java/libcore/net/mime.types?format=TEXT"))
loadMime(dataString: getAndroidSourceCode(from: "https://android.googlesource.com/platform/libcore/+/master/luni/src/main/java/libcore/net/android.mime.types?format=TEXT"))

print("\n")

var enumOutput = "public enum MimeType: String {\n"

var getExtensionOutput: String = "\tpublic static func get(fileExtension ext: String) -> MimeType? {\n"
getExtensionOutput += "\t\tswitch ext.lowercased() {\n"

var getMimeOutput: String = "\tpublic static func fileExtension(forMime mime: String) -> String? {\n"
getMimeOutput += "\t\tswitch mime.lowercased() {\n"

for mime in mimeOriginalOrder {
    let ext = mimeToExtension[mime]!
    getMimeOutput += "\t\tcase \"\(mime)\":\n"
    getMimeOutput += "\t\t\treturn \"\(ext)\"\n"
}

var addedEnumExt = Set<String>()

for ext in extensionOriginalOrder {
    let mime = extensionToMime[ext]!
    let primaryExt = mimeToExtension[mime]!
    let enumExt = mimeEnumCase(mime: primaryExt)
    if addedEnumExt.contains(enumExt) == false {
        addedEnumExt.insert(enumExt)
        enumOutput += "\tcase \(enumExt) = \"\(mime)\"\n"
    }
    getExtensionOutput += "\t\tcase \"\(ext)\":\n"
    getExtensionOutput += "\t\t\treturn .\(enumExt)\n"
}

enumOutput += "}"

getExtensionOutput += "\t\tdefault:\n"
getExtensionOutput += "\t\t\treturn nil\n"
getExtensionOutput += "\t\t}\n"
getExtensionOutput += "\t}\n\n"

getMimeOutput += "\t\tdefault:\n"
getMimeOutput += "\t\t\treturn nil\n"
getMimeOutput += "\t\t}\n"
getMimeOutput += "\t}\n\n"


var mimeOutput: String = "public class Mime {\n\n"
mimeOutput += getExtensionOutput
mimeOutput += getMimeOutput
mimeOutput += "}\n"

if path.count == 0 {
    print(enumOutput)
    print("\n\n\n")
    print(mimeOutput)
}
else {
    var enumUrl: URL = URL(fileURLWithPath: path)
    enumUrl.appendPathComponent("MimeType.swift")
    Updater.write(data: enumOutput, toFile: enumUrl)
    
    var mimeUrl: URL = URL(fileURLWithPath: path)
    mimeUrl.appendPathComponent("Mime.swift")
    Updater.write(data: mimeOutput, toFile: mimeUrl)
}

print("\nThank you for using MimeLibGenerator!\n\nOndrej Rafaj & team manGoweb UK! (http://www.mangoweb.cz/en)\n\n\n")

Example.run()


