import Foundation

let outpath = "/usr/local/src"
let outfile = "Package.swift"
let task = Process()
let pipe = Pipe()

task.standardOutput = pipe
task.standardError = pipe
task.arguments = ["-c", "swift package dump-package"]
task.launchPath = "/bin/bash"
try! task.run()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
let json = try! JSONSerialization.jsonObject(with: data, options : .allowFragments) as! [String: Any]

var packages = [String]()
var products = [String]()

var packageBlacklist = ["vapor"]
var productBlacklist = ["Vapor"]

func buildPackageStrings() {
    if let dependencies = json["dependencies"] as? [[String: Any]] {
        for dependency in dependencies {
            if let scm = dependency["scm"] as? [[String: Any]] {
                for data in scm {
                    let identity = data["identity"] as? String
                    let location = data["location"] as? String
                    let lowerBound = ((data["requirement"] as? [String:Any])?["range"] as? [[String:Any]])?[0]["lowerBound"] as? String
                    
                    guard let identity = identity, let location = location, let lowerBound = lowerBound else {
                        continue
                    }
                    if packageBlacklist.contains(identity) {
                        continue
                    }

                    let output = ".package(url: \"\(location)\", from: \"\(lowerBound)\"),"

                    packages.append(output)
                }
            }
        }
    }
}

func buildProductStrings() {
    if let targets = json["targets"] as? [[String: Any]] {
        for target in targets {
            if let dependencies = target["dependencies"] as? [[String: Any]] {
                for dependency in dependencies {
                    let values = dependency["product"]! as! [Any]
                    let identity = values[0] as? String
                    let package = values[1] as? String
                
                    guard let identity = identity, let package = package else {
                        continue
                    }
                    if productBlacklist.contains(identity) {
                        continue
                    }

                    let output = ".product(name: \"\(identity)\", package: \"\(package)\"),"

                    products.append(output)
                }
            }
        }
    }
}

func writePackageStrings() {
    let path = "\(outpath)/\(outfile)"
    var text = try! String(contentsOfFile: path)
    let pattern = #"(.package\(.*)"#
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(text.startIndex..<text.endIndex, in: text)

    regex.enumerateMatches(
        in: text,
        options: [],
        range: range
    ) { (match, _, stop) in
        guard let match = match else { return }

        let lastRange = Range(match.range(at: match.numberOfRanges - 1), in: text)
        let lastMatch = text.substring(with: lastRange!)
        var last = lastMatch
        if last.last != "," {
            last += ","
        }
        let replacement = last + "\n\t\t" + packages.joined(separator: ",\n\t\t")
        
        text = text.replacingOccurrences(of: lastMatch, with: replacement)

        stop.pointee = true
    }
    try! text.write(
        to: URL(fileURLWithPath: path),
        atomically: true,
        encoding: .utf8
    )
}

func writeProductStrings() {
    let path = "\(outpath)/\(outfile)"
    var text = try! String(contentsOfFile: path)
    let pattern = #"(.product\(.*)"#
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let range = NSRange(text.startIndex..<text.endIndex, in: text)

    regex.enumerateMatches(
        in: text,
        options: [],
        range: range
    ) { (match, _, stop) in
        guard let match = match else { return }
        
        let lastRange = Range(match.range(at: match.numberOfRanges - 1), in: text)
        let lastMatch = text.substring(with: lastRange!)
        var last = lastMatch
        if last.last != "," {
            last += ","
        }
        let replacement = last + "\n\t\t\t\t" + products.joined(separator: ",\n\t\t\t\t")
        
        text = text.replacingOccurrences(of: lastMatch, with: replacement)
        
        stop.pointee = true
    }
    try! text.write(
        to: URL(fileURLWithPath: path),
        atomically: true,
        encoding: .utf8
    )
}

buildPackageStrings()
buildProductStrings()
writePackageStrings()
writeProductStrings()
